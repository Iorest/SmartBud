//
//  ImportDataView+Chrome.swift
//  smartbud
//
//  Header (back / step title / progress) and the primary action bar.
//

import SwiftUI

extension ImportDataView {

    /// CSV from banks and payment apps is often GBK/GB18030 or UTF-16, not
    /// UTF-8. Reporting "Invalid File" for those made the whole feature look
    /// broken; try the encodings in order and only then give up.
    func decodeCSV(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        let gb18030 = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: gb18030))
    }

    @ViewBuilder
    var topBar: some View {
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
                    .background(
                        Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                    )
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
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
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
    }

    @ViewBuilder
    var actionBar: some View {
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
                        .background(
                            Color.DarkBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                        )
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
                                // Validate the whole column, not the eight
                                // preview rows: a bad row at line 9 used to
                                // fail the import after all seven steps.
                                guard validateAmounts(strings: columns[selectedColumn]) else {
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
                                guard !isAdvancing else { return }
                                isAdvancing = true
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
                                    isAdvancing = false
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
                        .background(
                            Color.DarkBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                        )
                }
                .buttonStyle(BouncyButton(duration: 0.2, scale: 0.8))
            }
    }
}

// MARK: - Processing state

extension ImportDataView {
    /// Digest → first import date for the last few files. One slot only
    /// caught A→A but missed A→B→A.
    static let importedFilesKey = "importedFileDigests"

    var duplicateWarningMessage: String {
        guard let duplicateDate else {
            return String.appLocalized(
                "This file was imported on this device before. Importing it again duplicates every row.")
        }
        let day = duplicateDate.formatted(
            Date.FormatStyle(locale: .appLocale).year().month().day())
        return String.appFormatted(
            "This file was imported on %@. Importing it again duplicates every row.", day)
    }

    @ViewBuilder
    var processingView: some View {
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

                HStack(spacing: SBSpace.small) {
                    Button(String.appLocalized("Back")) {
                        withAnimation { progress = 7; processingState = .loading }
                    }
                    .buttonStyle(.bordered)

                    Button(String.appLocalized("Close")) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, SBSpace.small)
            }
        }
    }
}
