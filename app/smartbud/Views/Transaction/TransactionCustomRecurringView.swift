import Foundation
import SwiftUI

struct CustomRecurringView: View {
    @Binding var repeatType: Int
    @Binding var repeatCoefficient: Int
    @Binding var showPicker: Bool

    var stringArray: [String] {
        return [
            "", "\(holdingCoefficient) days", "\(holdingCoefficient) weeks",
            "\(holdingCoefficient) months"
        ]
    }

    @Environment(\.dismiss) var dismiss

    @State private var lightHaptic = 0

    @State var holdingType = 0
    @State var holdingCoefficient = 0

    var body: some View {
        VStack(spacing: 35) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))

                        .foregroundStyle(Color.SubtitleText)
                        .padding(7)
                        .background(Color.SecondaryBackground, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String.appLocalized("Cancel"))

                Spacer()

                Text(String.appLocalized("Custom Interval"))
                    .font(.body.weight(.semibold))

                Spacer()

                Button {
                    repeatType = holdingType
                    repeatCoefficient = holdingCoefficient

                    lightHaptic &+= 1

                    dismiss()

                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))

                        .foregroundStyle(Color.IncomeGreen)
                        .padding(7)
                        .background(Color.IncomeGreen.opacity(0.23), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String.appLocalized("Done"))
            }

            HStack(spacing: 10) {
                Text(String.appLocalized("Repeats every"))
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                    .padding(.trailing, 3)

                VStack {
                    Button {
                        holdingCoefficient += 1
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(
                                    cornerRadius: SBRadius.pill,
                                    style: .continuous
                                )
                            )
                            .contentShape(Circle())
                            .opacity(holdingCoefficient == 30 ? 0.25 : 1)
                    }
                    .disabled(holdingCoefficient == 30)

                    Text("\(holdingCoefficient)")
                        .font(.title2.weight(.medium))
                        .padding(7)
                        .background {
                            RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                .fill(Color.SecondaryBackground)
                                .frame(width: 40, height: 40)
                        }

                    Button {
                        holdingCoefficient -= 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(
                                    cornerRadius: SBRadius.pill,
                                    style: .continuous
                                )
                            )
                            .contentShape(Circle())
                            .opacity(holdingCoefficient == 2 ? 0.25 : 1)
                    }
                    .disabled(holdingCoefficient == 2)
                }

                VStack {
                    Button {
                        holdingType -= 1
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(
                                    cornerRadius: SBRadius.pill,
                                    style: .continuous
                                )
                            )
                            .contentShape(Circle())
                            .opacity(holdingType == 1 ? 0.25 : 1)
                    }
                    .disabled(holdingType == 1)

                    Group {
                        if holdingType == 1 {
                            Text(String.appFormatted("^[%lld days](inflect: true)", holdingCoefficient))
                        } else if holdingType == 2 {
                            Text(String.appFormatted("^[%lld weeks](inflect: true)", holdingCoefficient))
                        } else if holdingType == 3 {
                            Text(String.appFormatted("^[%lld months](inflect: true)", holdingCoefficient))
                        }
                    }
                    .font(.title2.weight(.medium))
                    .padding(7)
                    .background {
                        RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                            .fill(Color.SecondaryBackground)
                            .frame(height: 40)
                    }

                    Button {
                        holdingType += 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(
                                    cornerRadius: SBRadius.pill,
                                    style: .continuous
                                )
                            )
                            .contentShape(Circle())
                            .opacity(holdingType == 3 ? 0.25 : 1)
                    }
                    .disabled(holdingType == 3)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(13)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            holdingType = repeatType
            holdingCoefficient = repeatCoefficient
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }
}
