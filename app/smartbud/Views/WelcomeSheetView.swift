//
//  WelcomeSheetView.swift
//  smartbud
//
//  Created by Iorest on 22/8/22.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

struct WelcomeSheetFeatureRow: Hashable {
    let icon: String
    let header: String
    let subtitle: String
}

struct WelcomeSheetView: View {

    @Query(sort: [SortDescriptor(\CategoryModel.dateCreated)])
    private var categories: [CategoryModel]

    @State var firstPage = true
    @State var visibleLines: Int = 0

    let timer = Timer.publish(every: 0.16, on: .main, in: .common).autoconnect()

    let welcomeFeatures = [
        WelcomeSheetFeatureRow(icon: "list.bullet.rectangle.fill", header: "welcome_header_1", subtitle: "welcome_subtitle_1"),
        WelcomeSheetFeatureRow(icon: "chart.bar.xaxis", header: "welcome_header_2", subtitle: "welcome_subtitle_2"),
        WelcomeSheetFeatureRow(icon: "archivebox.fill", header: "welcome_header_3", subtitle: "welcome_subtitle_3")
    ]

    var body: some View {
        Group {
            if firstPage {
                VStack(spacing: SBSpace.xl) {
                    VStack(spacing: SBSpace.xxs) {
                        Text(String.appLocalized("app_name"))
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.PrimaryText)

                        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)

                    VStack(alignment: .leading, spacing: SBSpace.l) {
                        ForEach(welcomeFeatures.indices, id: \.self) { rowIndex in
                            if rowIndex < visibleLines {
                                HStack(alignment: .top, spacing: SBSpace.s) {
                                    Image(systemName: welcomeFeatures[rowIndex].icon)
                                        .font(.title2)
                                        .foregroundStyle(Color.SubtitleText)
                                        .frame(width: 36, alignment: .leading)

                                    VStack(alignment: .leading, spacing: SBSpace.xxs) {
                                        Text(LocalizedStringKey(welcomeFeatures[rowIndex].header))
                                            .font(.headline)
                                            .foregroundStyle(Color.PrimaryText)

                                        Text(LocalizedStringKey(welcomeFeatures[rowIndex].subtitle))
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .foregroundStyle(Color.SubtitleText)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onReceive(timer) { _ in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if visibleLines < welcomeFeatures.count {
                                visibleLines += 1
                            } else {
                                timer.upstream.connect().cancel()
                            }
                        }
                    }

                    Button {
                        withAnimation {
                            firstPage = false
                        }
                    } label: {
                        Text("Get Started")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(SBSpace.l)
            } else {
                CategoryView(mode: .welcome)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}
