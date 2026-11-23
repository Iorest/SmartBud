//
//  ImportDataView+Steps.swift
//  smartbud
//
//  The four wizard steps. Each reads the view's own state, so they are not
//  reusable on their own — this only exists to keep `body` scannable.
//

import SwiftUI

extension ImportDataView {

    /// Step 1: what the CSV needs to look like.
    @ViewBuilder
    var stepPointers: some View {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline.weight(.medium))

                Text("Additional Pointers")
                    .font(.body.weight(.semibold))

                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .foregroundStyle(Color.IncomeGreen)
            .background(
                Color.IncomeGreen.opacity(0.23),
                in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
            )
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(pointers.indices, id: \.self) { index in
                        pointerView(number: index + 1, text: pointers[index])
                    }
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            }
    }

    /// Steps 2-5: pick which column maps to category / note / date / amount.
    @ViewBuilder
    var stepMapping: some View {
            VStack(spacing: 10) {
                Text("Sampled Rows from Import CSV")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier(AccessibilityID.importPreview)

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
                                            .background(
                                                Color(labels[index].label).opacity(0.23),
                                                in: RoundedCorner(radius: 10, corners: [.topLeft, .topRight])
                                            )
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
                                    .background(
                                        Color.DarkBackground,
                                        in: RoundedCorner(radius: 10, corners: [.topLeft, .topRight])
                                    )

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
    }

    /// Step 6: match the CSV's category values to existing categories.
    @ViewBuilder
    var stepLinking: some View {
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
                        .background(
                            Color.SecondaryBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                        )
                }
                .onChange(of: dateFormatString) { _, newValue in
                    let dateFormatter = DateFormatter()
                    // Same rule as the importer, otherwise the checkmark can
                    // disagree with how the dates are actually read.
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = .current
                    dateFormatter.dateFormat = newValue

                    if dateFormatter.date(from: sampleDateString) != nil {
                        validDateFormatString = true
                    } else {
                        validDateFormatString = false
                    }
                }
            }
    }

    /// Step 7: confirmation before writing.
    @ViewBuilder
    var stepSummary: some View {
            VStack(alignment: .leading, spacing: SBSpace.small) {
                HStack {
                    Text(String.appLocalized("Import into"))
                        .font(.subheadline)
                        .foregroundStyle(Color.SubtitleText)

                    Spacer(minLength: SBSpace.small)

                    Picker(String.appLocalized("Import into"), selection: $importAccountID) {
                        Text(String.appLocalized("No Account")).tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text("\(account.wrappedEmoji) \(account.wrappedName)")
                                .tag(Optional(account.id))
                        }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, SBSpace.medium)

                Text(String
                    .appFormatted("%lld/^[%lld category](inflect: true) linked", numberOfLinkedCategories,
                        uniqueCategories.count))
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.horizontal, SBSpace.medium)

                List {
                    ForEach(uniqueCategories.indices, id: \.self) { categoryIndex in
                        let isIncome = uniqueCategories[categoryIndex].income
                        let pool = isIncome ? incomeCategories : expenseCategories

                        VStack(alignment: .leading, spacing: SBSpace.extraSmall) {
                            HStack(spacing: SBSpace.small) {
                                Text(uniqueCategories[categoryIndex].excelValue)
                                    .font(.headline)
                                    .lineLimit(1)

                                Spacer(minLength: SBSpace.extraSmall)

                                Picker(String.appLocalized("Type"),
                                       selection: $uniqueCategories[categoryIndex].income) {
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

                            Picker(String.appLocalized("Category"), selection: $uniqueCategories[categoryIndex]
                                .category) {
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
}
