//
//  ImportDataView.swift
//  smartbud
//
//  Created by Iorest on 21/8/23.
//

import CryptoKit
import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import UniformTypeIdentifiers

struct ColumnLabel {
    let image: String
    let label: String
}

enum ProcessingState {
    case loading, success, error
}

struct MatchedCategory: Hashable {
    let excelValue: String
    var income: Bool
    var category: CategoryModel?

}

extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

struct ImportDataView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(CategoryViewModel.self) var categoryVM

    /// The wizard writes one batch, so one account. Rows used to be written
    /// with no account at all: they counted in the totals but moved no
    /// balance, and every account total disagreed with the ledger.
    @Query(sort: [SortDescriptor(\AccountModel.order)]) var accounts: [AccountModel]
    /// Picked by id: `AccountModel` is not `Hashable`, and the picker only
    /// needs a stable selection.
    @State var importAccountID: UUID?
    /// Guards the 500 ms "continue" animation against a second tap.
    @State var isAdvancing = false

    @State var exportSample = false
    @State var importing = false

    @State var data = ""
    /// SHA-256 of the picked file. Importing the same file twice doubles the
    /// ledger, and there is no way to tell the copies apart afterwards.
    @State var pendingDigest: String?
    @State private var showDuplicateWarning = false
    @State var duplicateDate: Date?
    @State var rows = [[String]]()
    @State var numberOfRows: Int = 0
    @State var displayedColumns = [[String]]()
    @State var columns = [[String]]()

    @State var remainingColumns = [Int]()
    @State var selectedColumns = [Int]()

    @State var lightHaptic = 0

    var indexColumnWidth: CGFloat {
        let additionalPadding: Double

        if dynamicTypeSize > .xLarge {
            additionalPadding = 10
        } else {
            additionalPadding = 0
        }

        if numberOfRows < 10 {
            return "9".widthOfRoundedString(size: 15, weight: .bold) + 16.0 + additionalPadding
        } else if numberOfRows < 100 {
            return "99".widthOfRoundedString(size: 15, weight: .bold) + 16.0 + additionalPadding
        } else {
            return "999".widthOfRoundedString(size: 15, weight: .bold) + 16.0 + additionalPadding
        }
    }

    @State var progress = 1

    @State var selectedColumn = 0
    @State var columnSelectionCompleted = false
    @State var sampleDateString = ""
    @State var dateFormatString = ""
    @State var validDateFormatString = false
    @State var uniqueCategories: [MatchedCategory] = .init()

    @State var processingState = ProcessingState.loading
    @State var errorMessage = "Invalid dates in date column."
    @State var confettiNumber = 0
    @State var showConfetti = false

    var numberOfLinkedCategories: Int {
        uniqueCategories.filter { $0.category != nil }.count
    }

    @State var showToast = false
    @State var toastMessage: String = String.appLocalized("Invalid File")

    @State var showingCategoryView = false

    // just for the adding of transactions
    @State var income = false

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var columnWidth: CGFloat {
        if dynamicTypeSize > .xLarge {
            return 150
        } else {
            return 100
        }
    }

    let instructions: [InstructionHeadings] = [
        InstructionHeadings(
            title: String.appLocalized("Import transactions"),
            subtitle: String
                .appLocalized("Begin by adding a CSV file with 4 columns: amount, note, date, and category.")),
        InstructionHeadings(
            title: String.appLocalized("Assign category column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds "
                 + "to the categories of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign note column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds "
                 + "to the notes/subtitles of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign date column"),
            subtitle: String
                .appLocalized("Select a column from your import that corresponds to the dates of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign amount column"),
            subtitle: String
                .appLocalized("Select a column from your import that corresponds to the values of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Indicate date format"),
            subtitle: String
                .appLocalized("Referencing this article, state the format of the dates in the assigned column.")),
        InstructionHeadings(
            title: String.appLocalized("Link categories"),
            subtitle: String.appLocalized("Match values found in the 'Category' column "
                 + "to the corresponding categories in SmartBud.")),
        InstructionHeadings(
            title: String.appLocalized("Processing import"),
            subtitle: String.appLocalized("Please wait while we process your new transactions."))
    ]

    let labels: [ColumnLabel] = [
        ColumnLabel(image: "square.grid.2x2.fill", label: String.appLocalized("Category")),
        ColumnLabel(image: "doc.plaintext.fill", label: String.appLocalized("Note")),
        ColumnLabel(image: "calendar", label: String.appLocalized("Date")),
        ColumnLabel(image: "dollarsign.circle.fill", label: String.appLocalized("Amount"))
    ]

    let pointers = [
        String.appLocalized("Amounts may include currency symbols, thousands separators or parentheses; "
             + "the number is read as-is."),
        String.appLocalized("All dates should be of a consistent, recognizable format. If no timestamps "
             + "are provided, the time of transaction will default to 12:00 am."),
        String.appLocalized("Fields containing commas are fine as long as they are wrapped in double quotes.")
    ]

    var incomeCategories: [CategoryModel] {
        categoryVM.incomeCategories
    }

    var expenseCategories: [CategoryModel] {
        categoryVM.expenseCategories
    }

    var body: some View {
        VStack(spacing: 0) {
            if progress == 8 {
                processingView
                    .frame(maxHeight: .infinity)
            } else {
                topBar

                if progress == 1 {
                    stepPointers
                } else if progress < 6 {
                    stepMapping
                } else if progress == 6 {
                    stepLinking
                } else if progress == 7 {
                    stepSummary
                }

                Spacer()

                actionBar
            }
        }
        .padding(20)

        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard)
        .appBackground()
        .onAppear {
            categoryVM.load()
            AccountViewModel.shared.load()
            if importAccountID == nil {
                importAccountID = AccountViewModel.shared.defaultAccount(
                    lastUsedID: UserDefaults.appGroup.string(forKey: "lastAccountID"))?.id
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            switch result {
            case let .success(file):
                guard file.startAccessingSecurityScopedResource() else {
                    showToast = true
                    toastMessage = String.appLocalized("Unable to access file")
                    return
                }
                defer { file.stopAccessingSecurityScopedResource() }

                do {
                    let raw = try Data(contentsOf: file)
                    guard let message = decodeCSV(raw) else {
                        showToast = true
                        toastMessage = String.appLocalized(
                            "This file's text encoding is not supported. Save it as a UTF-8 CSV and try again.")
                        return
                    }

                    let digest = SHA256.hash(data: raw)
                        .map { String(format: "%02x", $0) }
                        .joined()
                    pendingDigest = digest
                    data = message

                    let history = UserDefaults.appGroup
                        .dictionary(forKey: Self.importedFilesKey) as? [String: Date] ?? [:]
                    if let importedAt = history[digest] {
                        duplicateDate = importedAt
                        showDuplicateWarning = true
                        return
                    }
                    processCSV()
                } catch {
                    showToast = true
                    toastMessage = String.appLocalized("Import Failed")
                }
            case .failure:
                showToast = true
                toastMessage = String.appLocalized("Import Failed")
            }
        }
        .sheet(isPresented: $exportSample) {
            if let url = Bundle.main.url(forResource: "sample", withExtension: "csv") {
                #if os(macOS)
                VStack(spacing: 16) {
                    Text(url.lastPathComponent)
                        .font(.body.weight(.semibold))
                    ShareLink(item: url)
                }
                .padding(24)
                #else
                ActivityViewController(activityItems: [url])
                #endif
            }
        }
        .sheet(isPresented: $showingCategoryView) {
                NewCategoryAlert(income: $income, bottomSpacers: false, budgetMode: false)
                    .presentationDetents([.medium, .large])
        }
        .alert(String.appLocalized("Import this file again?"),
               isPresented: $showDuplicateWarning) {
            Button(String.appLocalized("Import Anyway")) {
                showDuplicateWarning = false
                processCSV()
            }
            Button(String.appLocalized("Cancel"), role: .cancel) {
                showDuplicateWarning = false
            }
        } message: {
            Text(duplicateWarningMessage)
        }
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .onChange(of: processingState) { _, newValue in
            if newValue == .success {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    dismiss()
                }
            }
        }
        .confettiOverlay(isActive: $showConfetti)
        .onChange(of: confettiNumber) { _, _ in showConfetti = true }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }

}
