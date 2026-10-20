//
//  ImportDataView+Chrome.swift
//  smartbud
//
//  Header (back / step title / progress) and the primary action bar.
//

import SwiftUI

extension ImportDataView {

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
