//
//  ImportDataView.swift
//  smartbud
//
//  Created by Iorest on 21/8/23.
//

import Foundation
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

    @State private var exportSample = false
    @State private var importing = false

    @State private var data = ""
    @State private var rows = [[String]]()
    @State private var numberOfRows: Int = 0
    @State private var displayedColumns = [[String]]()
    @State private var columns = [[String]]()

    @State private var remainingColumns = [Int]()
    @State private var selectedColumns = [Int]()

    @State private var lightHaptic = 0

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
    @State private var showConfetti = false

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
            subtitle: String.appLocalized("Begin by adding a CSV file with 4 columns: amount, note, date, and category.")),
        InstructionHeadings(
            title: String.appLocalized("Assign category column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds to the categories of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign note column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds to the notes/subtitles of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign date column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds to the dates of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Assign amount column"),
            subtitle: String.appLocalized("Select a column from your import that corresponds to the values of your transactions.")),
        InstructionHeadings(
            title: String.appLocalized("Indicate date format"),
            subtitle: String.appLocalized("Referencing this article, state the format of the dates in the assigned column.")),
        InstructionHeadings(
            title: String.appLocalized("Link categories"),
            subtitle: String.appLocalized("Match values found in the 'Category' column to the corresponding categories in SmartBud.")),
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
        String.appLocalized("Ensure that the values in the 'Amount' column do not contain any currency symbols."),
        String.appLocalized("All dates should be of a consistent, recognizable format. If no timestamps are provided, the time of transaction will default to 12:00 am."),
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
                VStack(spacing: 15) {
                    switch processingState {
                    case .loading:
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(0.8)

                        Text("Processing Import")
                            .font(.title2.weight(.medium))

                            .foregroundStyle(Color.SubtitleText)
                    case .success:

                        Image(systemName: "checkmark")
                            .font(.title2.weight(.semibold))

                            .foregroundStyle(Color.IncomeGreen)
                            .frame(width: 35, height: 35)
                            .background(Color.IncomeGreen.opacity(0.3), in: Circle())

                        Text("Import Successful")
                            .font(.title2.weight(.medium))

                            .foregroundStyle(Color.IncomeGreen)
                    case .error:
                        Image(systemName: "x")
                            .font(.title2.weight(.semibold))

                            .foregroundStyle(Color.AlertRed)
                            .frame(width: 35, height: 35)
                            .background(Color.Alert.opacity(0.3), in: Circle())

                        Text("Import Failed")
                            .font(.title2.weight(.medium))

                            .foregroundStyle(Color.PrimaryText)

                        Text(errorMessage)
                            .font(.subheadline.weight(.medium))

                            .foregroundStyle(Color.SubtitleText)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                HStack {
                        Button {
                            if progress == 2 {
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                    progress -= 1
                                }
                            } else if progress > 6 {
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                    progress -= 1
                                }
                            } else if progress > 2 {
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                    if let removedColumn = selectedColumns.popLast() {
                                        remainingColumns.append(removedColumn)
                                        remainingColumns.sort()
                                        selectedColumn = remainingColumns[0]
                                        columnSelectionCompleted = false

                                        progress -= 1
                                    }
                                }
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: progress > 1 ? "chevron.left" : "xmark")
                                .font(.callout.weight(.semibold))

                                .foregroundStyle(Color.SubtitleText)
                                .padding(8)
                                .background(Color.SecondaryBackground, in: Circle())
                        }
                        .contentTransition(.symbolEffect(.replace.downUp.wholeSymbol))

                    Spacer()

                    HStack(spacing: SBSpace.xxs) {
                        ProgressView(value: Double(max(0, progress - 1)), total: 7)
                            .frame(width: 72)
                        Text("\(max(0, progress - 1))/7")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                .overlay {
                    if showToast {
                        HStack(spacing: 6.5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))

                                .foregroundStyle(Color.AlertRed)

                            Text(toastMessage)
                                .font(.callout.weight(.semibold))

                                .foregroundStyle(Color.AlertRed)
                        }
                        .padding(8)
                        .background(Color.AlertRed.opacity(0.23), in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        .frame(width: 250)
                    }
                }
                .padding(.bottom, 50)
                .animation(.easeInOut, value: progress > 1)

                VStack(alignment: .leading, spacing: 5) {
                    if progress == 6 {
                        HStack {
                            Text("Indicate date format")
                                .foregroundStyle(Color.PrimaryText)
                                .font(.title2.weight(.semibold))

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        Text(
                            AttributedString(String.appLocalized("Referencing "))
                                + makeAttributedString()
                                + AttributedString(
                                    String.appLocalized(", state the format of the dates in the assigned column."))
                        )
                            .foregroundStyle(Color.SubtitleText)
                            .font(.body.weight(.medium))

                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack {
                            Text(instructions[progress - 1].title)
                                .foregroundStyle(Color.PrimaryText)
                                .font(.title2.weight(.semibold))

                            if progress == 7 {
                                Button {
                                    showingCategoryView = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.SubtitleText)
                                        .padding(4)
                                        .background(Color.SecondaryBackground, in: Circle())
                                        .contentShape(Circle())
                                }
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        Text(instructions[progress - 1].subtitle)
                            .foregroundStyle(Color.SubtitleText)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .containerRelativeFrame(.vertical) { height, _ in
                    height / (dynamicTypeSize > .xLarge ? 5.3 : 5.8)
                }
                .padding(.bottom, 10)

                if progress == 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.subheadline.weight(.medium))

                        Text("Additional Pointers")
                            .font(.body.weight(.semibold))

                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .foregroundStyle(Color.IncomeGreen)
                    .background(Color.IncomeGreen.opacity(0.23), in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                    .padding(.bottom, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(pointers.indices, id: \.self) { index in
                                PointerView(number: index + 1, text: pointers[index])
                            }
                        }
                    }
                } else if progress < 6 {
                    VStack(spacing: 10) {
                        Text("Sampled Rows from Import CSV")
                            .font(.subheadline.weight(.semibold))

                            .foregroundStyle(Color.SubtitleText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    ForEach(0..<(numberOfRows + 1), id: \.self) { number in
                                        if number == 0 {
                                            Rectangle()
                                                .fill(Color.PrimaryBackground)
                                                .frame(width: indexColumnWidth, height: 30, alignment: .leading)
                                        } else {
                                            Text("\(number)")
                                                .foregroundStyle(Color.SubtitleText)
                                                .font(.subheadline.weight(.bold))

                                                .padding(.horizontal, 8)
                                                .frame(width: indexColumnWidth, height: 30, alignment: .leading)
                                                .overlay(Rectangle().stroke(Color.Outline, lineWidth: 1))
                                        }
                                    }
                                }
                                .background(Color.SecondaryBackground.opacity(0.6))

                                HStack(spacing: 0) {
                                    ForEach(displayedColumns.indices, id: \.self) { columnIndex in

                                        VStack(spacing: 0) {
                                            if selectedColumns.contains(columnIndex) {
                                                if let index = selectedColumns.firstIndex(of: columnIndex) {
                                                    HStack(spacing: 4.5) {
                                                        Image(systemName: labels[index].image)
                                                            .font(.caption.weight(.semibold))

                                                        Text(labels[index].label)
                                                            .font(.subheadline.weight(.semibold))

                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .frame(width: columnWidth, height: 30, alignment: .leading)
                                                    .foregroundStyle(Color(labels[index].label))
                                                    .background(Color(labels[index].label).opacity(0.23), in: RoundedCorner(radius: 10, corners: [.topLeft, .topRight]))
                                                }
                                            } else {
                                                Rectangle()
                                                    .fill(Color.PrimaryBackground)
                                                    .frame(width: columnWidth, height: 30, alignment: .leading)
                                            }

                                            VStack(spacing: 0) {
                                                ForEach(displayedColumns[columnIndex], id: \.self) { value in
                                                    Text(value)
                                                        .foregroundStyle(Color.PrimaryText)
                                                        .font(.subheadline.weight(.medium))

                                                        .padding(.horizontal, 8)
                                                        .frame(width: columnWidth, height: 30, alignment: .leading)
                                                        .overlay(Rectangle().stroke(Color.Outline, lineWidth: 1))
                                                    //
                                                }
                                            }
                                            .onTapGesture {
                                                if progress >= 2 {
                                                    if remainingColumns.contains(columnIndex) {
                                                        withAnimation {
                                                            selectedColumn = columnIndex
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .overlay(alignment: .leading) {
                                    if !columnSelectionCompleted && progress < 6 {
                                        VStack(spacing: 0) {
                                            HStack(spacing: 4.5) {
                                                Image(systemName: labels[progress - 2].image)
                                                    .font(.caption.weight(.semibold))

                                                Text(labels[progress - 2].label)
                                                    .font(.subheadline.weight(.semibold))

                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.horizontal, 10)
                                            .frame(width: columnWidth + 2, height: 30, alignment: .leading)
                                            .foregroundStyle(Color.LightIcon)
                                            .background(Color.DarkBackground, in: RoundedCorner(radius: 10, corners: [.topLeft, .topRight]))

                                            Rectangle()
                                                .stroke(Color.DarkBackground, lineWidth: 2)
                                                .frame(width: columnWidth)
                                                .frame(maxHeight: .infinity)
                                        }
                                        .offset(x: CGFloat(CGFloat(selectedColumn) * columnWidth))
                                    }
                                }
                            }
                            .padding(2)
                        }
                    }
                } else if progress == 6 {
                    VStack(spacing: 10) {
                        Text("Sample from 'Date' Column")
                            .font(.subheadline.weight(.semibold))

                            .foregroundStyle(Color.SubtitleText)

                        Text(sampleDateString)
                            .font(.title3.weight(.semibold))

                            .foregroundStyle(Color.PrimaryText)
                            .frame(width: 300, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                                    .stroke(Color.Outline, lineWidth: 2)
                            )
                            .padding(.bottom, 30)

                        HStack(spacing: 7) {
                            Image(systemName: "calendar")
                                .font(.callout.weight(.semibold))

                                .foregroundStyle(Color.SubtitleText)

                            TextField("Date Format", text: $dateFormatString)
                                .foregroundStyle(Color.PrimaryText)
                                .font(.title3.weight(.semibold))

                                .frame(maxWidth: .infinity)

                            if validDateFormatString {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.callout.weight(.semibold))

                                    .foregroundStyle(Color.IncomeGreen)
                            } else if !validDateFormatString && dateFormatString != "" {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 300, height: 40)
                        .background {
                            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                                .stroke(Color.SubtitleText, lineWidth: 2)
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
                        }
                        .onChange(of: dateFormatString) { _, newValue in
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = newValue

                            if dateFormatter.date(from: sampleDateString) != nil {
                                validDateFormatString = true
                            } else {
                                validDateFormatString = false
                            }
                        }
                    }
                } else if progress == 7 {
                    VStack(alignment: .leading, spacing: SBSpace.s) {
                        Text(String.appFormatted("%lld/^[%lld category](inflect: true) linked", numberOfLinkedCategories, uniqueCategories.count))
                            .font(.subheadline)
                            .foregroundStyle(Color.SubtitleText)
                            .padding(.horizontal, SBSpace.m)

                        List {
                            ForEach(uniqueCategories.indices, id: \.self) { categoryIndex in
                                let isIncome = uniqueCategories[categoryIndex].income
                                let pool = isIncome ? incomeCategories : expenseCategories

                                VStack(alignment: .leading, spacing: SBSpace.xs) {
                                    HStack(spacing: SBSpace.s) {
                                        Text(uniqueCategories[categoryIndex].excelValue)
                                            .font(.headline)
                                            .lineLimit(1)

                                        Spacer(minLength: SBSpace.xs)

                                        Picker("", selection: $uniqueCategories[categoryIndex].income) {
                                            Text(String.appLocalized("Expense")).tag(false)
                                            Text(String.appLocalized("Income")).tag(true)
                                        }
                                        .pickerStyle(.segmented)
                                        .labelsHidden()
                                        .frame(width: 150)
                                        .onChange(of: uniqueCategories[categoryIndex].income) { _, newValue in
                                            if let selected = uniqueCategories[categoryIndex].category,
                                               selected.income != newValue {
                                                uniqueCategories[categoryIndex].category = nil
                                            }
                                        }
                                    }

                                    Picker(String.appLocalized("Category"), selection: $uniqueCategories[categoryIndex].category) {
                                        Text(String.appLocalized("Select")).tag(CategoryModel?.none)
                                        ForEach(pool) { category in
                                            Text("\(category.wrappedEmoji) \(category.wrappedName)")
                                                .tag(Optional(category))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        #if os(macOS)
                        .listStyle(.inset)
                        #else
                        .listStyle(.insetGrouped)
                        #endif
                        .scrollContentBackground(.hidden)
                    }
                }

                Spacer()

                if progress == 1 {
                    VStack(spacing: 13) {
                        Button {
                            lightHaptic &+= 1

                            importing = true

                        } label: {
                            HStack(spacing: 6) {
                                Text("Import")
                                    .font(.title3.weight(.semibold))

                                Image(systemName: "square.and.arrow.up.fill")
                                    .font(.subheadline.weight(.semibold))

                            }
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.LightIcon)
                            .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                        }
                        .buttonStyle(BouncyButton(duration: 0.2, scale: 0.8))

                        Button {
                            exportSample = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Sample Sheet")
                                    .underline()
                                    .font(.body.weight(.semibold))

                            }
                            .foregroundStyle(Color.SubtitleText)
                        }
                    }

                } else {
                    Button {
                        if progress == 7 {
                            if numberOfLinkedCategories == uniqueCategories.count {
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                    progress += 1
                                }

                                importData()
                            } else {
                                showToast = true
                                toastMessage = String.appLocalized("Unlinked Categories")
                            }

                        } else if progress > 5 {
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                progress += 1
                            }
                        } else {
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                guard !remainingColumns.isEmpty else { return }

                                if progress == 4 {
                                    let sample = displayedColumns[selectedColumn][0]

                                    guard sample.containsDigits else {
                                        showToast = true
                                        toastMessage = String.appLocalized("Invalid Column")
                                        return
                                    }
                                }

                                if progress == 5 {
                                    let stringColumn = displayedColumns[selectedColumn]

                                    guard validateDoubles(strings: stringColumn) else {
                                        showToast = true
                                        toastMessage = String.appLocalized("Invalid Column")
                                        return
                                    }
                                }

                                // remove from possible pool
                                remainingColumns.removeAll { $0 == selectedColumn }

                                // add to holding pool
                                selectedColumns.append(selectedColumn)

                                if progress < 5 {
                                    guard !remainingColumns.isEmpty else {
                                        showToast = true
                                        toastMessage = String.appLocalized("Insufficient Columns")
                                        return
                                    }
                                    selectedColumn = remainingColumns[0]
                                }

                                // reset selected column

                                if progress == 5 {
                                    let dateColumnIndex = selectedColumns[2]
                                    sampleDateString = displayedColumns[dateColumnIndex][0]

                                    if let deducedFormat = deduceDateFormat(from: sampleDateString) {
                                        dateFormatString = deducedFormat
                                        validDateFormatString = true
                                    }

                                    let categoryColumnIndex = selectedColumns[0]
                                    uniqueCategories = columns[categoryColumnIndex].unique().map {
                                        MatchedCategory(excelValue: $0, income: false)
                                    }

                                    columnSelectionCompleted = true
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(500))
                                        withAnimation {
                                            progress += 1
                                        }
                                    }
                                } else {
                                    progress += 1
                                }
                            }
                        }
                    } label: {
                        Text(String.appLocalized("Continue"))
                            .font(.title3.weight(.semibold))

                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.LightIcon)
                            .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                    }
                    .buttonStyle(BouncyButton(duration: 0.2, scale: 0.8))
                }
            }
        }
        .padding(20)

        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard)
        .appBackground()
        .onAppear {
            categoryVM.load()
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
                    guard let message = try String(data: Data(contentsOf: file), encoding: .utf8) else {
                        showToast = true
                        toastMessage = String.appLocalized("Invalid File")
                        return
                    }

                    data = message
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

    func validateDoubles(strings: [String]) -> Bool {
        for string in strings {
            if let _ = Double(string) {
                // Valid double
            } else {
                return false // Invalid double found
            }
        }
        return true // All strings are valid doubles
    }

    func processCSV() {
        do {
            let table = try CSVTable(text: data)
            var parsedRows = table.rows

            // Drop a text-only header row (no digits in any cell).
            if let first = parsedRows.first,
               first.allSatisfy({ !$0.containsDigits }) {
                parsedRows.removeFirst()
            }

            guard !parsedRows.isEmpty else {
                showToast = true
                toastMessage = String.appLocalized("Invalid File")
                return
            }

            let maxColumnCount = parsedRows.map(\.count).max() ?? 0
            guard maxColumnCount > 3 else {
                showToast = true
                toastMessage = String.appLocalized("Invalid File")
                return
            }

            rows = parsedRows

            // Pad ragged rows so every column keeps the same row alignment.
            let padded = parsedRows.map { row in
                row + Array(repeating: "", count: maxColumnCount - row.count)
            }

            var holdingColumns: [[String]] = Array(repeating: [], count: maxColumnCount)
            for row in padded {
                for (index, value) in row.enumerated() {
                    holdingColumns[index].append(value)
                }
            }

            columns = holdingColumns
            displayedColumns = holdingColumns.map { Array($0.prefix(8)) }
            numberOfRows = displayedColumns.first?.count ?? 0
            remainingColumns = Array(0..<maxColumnCount)

            withAnimation {
                progress += 1
            }
        } catch {
            showToast = true
            toastMessage = String.appLocalized("Invalid File")
        }
    }

    /// Validates every row first, then writes the whole batch with one save.
    /// A bad row aborts the import with zero rows written.
    func importData() {
        guard selectedColumns.count > 3 else {
            processingState = .error
            errorMessage = String.appLocalized("请先完成列匹配。")
            return
        }

        let categoryColumnIndex = selectedColumns[0]
        let noteColumnIndex = selectedColumns[1]
        let dateColumnIndex = selectedColumns[2]
        let amountColumnIndex = selectedColumns[3]
        let maxIndex = max(categoryColumnIndex, noteColumnIndex, dateColumnIndex, amountColumnIndex)

        guard !dateFormatString.isEmpty else {
            processingState = .error
            errorMessage = String.appLocalized("请先选择日期格式。")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = dateFormatString

        let categoryDictionary: [String: CategoryModel] = Dictionary(
            uniqueCategories.compactMap { entry in
                entry.category.map { (entry.excelValue, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        struct Draft {
            let note: String
            let category: CategoryModel
            let amount: Double
            let date: Date
        }

        var drafts: [Draft] = []
        drafts.reserveCapacity(rows.count)

        for (offset, row) in rows.enumerated() {
            let line = offset + 1

            guard row.count > maxIndex else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行缺少列，请检查 CSV。"), line)
                return
            }
            guard let transactionDate = dateFormatter.date(from: row[dateColumnIndex]) else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的日期无法解析。"), line)
                return
            }
            guard let rowCategory = categoryDictionary[row[categoryColumnIndex]] else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的分类未匹配。"), line)
                return
            }
            guard let transactionAmount = Double(row[amountColumnIndex]) else {
                processingState = .error
                errorMessage = String(format: String.appLocalized("第 %d 行的金额无法解析。"), line)
                return
            }

            drafts.append(Draft(
                note: row[noteColumnIndex],
                category: rowCategory,
                amount: abs(transactionAmount),
                date: transactionDate
            ))
        }

        for draft in drafts {
            let txn = TransactionModel(
                note: draft.note,
                category: draft.category,
                income: draft.category.income,
                amount: draft.amount,
                date: draft.date
            )
            DataRepository.shared.insert(txn)
        }

        guard DataRepository.shared.save() else {
            processingState = .error
            errorMessage = DataRepository.shared.lastSaveError
                ?? String.appLocalized("导入失败，未写入任何数据。")
            return
        }

        withAnimation {
            processingState = .success
            confettiNumber += 1
        }
    }

    func deduceDateFormat(from dateString: String) -> String? {
        let dateFormats = ["yyyy-MM-dd", "dd-MM-yyyy", "MM-dd-yyyy",
                           "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy",
                           "yyyyMMdd", "ddMMyyyy", "MMddyyyy", "yyyy-MM-dd HH:mm:ss Z",
                           "dd/MM/yyyy HH:mm:ss"]

        let dateFormatter = DateFormatter()

        for dateFormat in dateFormats {
            dateFormatter.dateFormat = dateFormat
            if let _ = dateFormatter.date(from: dateString) {
                return dateFormat
            }
        }

        return nil
    }

    func makeAttributedString() -> AttributedString {
        var string = AttributedString("this article")
        string.foregroundColor = Color.PrimaryText
        string.link = URL(string: "https://pro.arcgis.com/en/pro-app/latest/help/mapping/time/convert-string-or-numeric-time-values-into-data-format.htm")
        string.underlineColor = UIColor(Color.PrimaryText)
        string.underlineStyle = .single

        return string
    }

    @ViewBuilder
    func PointerView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.SecondaryBackground)

                Text("\(number)")
                    .font(.body.weight(.bold))

                    .foregroundStyle(Color.SubtitleText)
            }
            .frame(width: 25, height: 25)

            Text(text)
                .font(.body.weight(.medium))

                .foregroundStyle(Color.PrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if !os(macOS)
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
#endif

#if os(macOS)
struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// AppKit has no per-corner rounding helper; rounding all four corners is
/// visually equivalent for the small tab labels that use this shape.
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: min(radius, min(rect.width, rect.height) / 2))
    }
}
#else
typealias RectCorner = UIRectCorner

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
#endif
