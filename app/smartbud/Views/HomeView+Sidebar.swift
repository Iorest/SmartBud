//
//  HomeView+Sidebar.swift
//  smartbud
//
//  Sidebar model for the wide layouts (iPad regular width, Mac). Kept out of
//  `HomeView.swift` so that file stays within a reviewable length.
//

import Foundation

extension HomeView {
    /// Sidebar entries for the wide layout. `id` matches the tab tags.
    struct SidebarSection: Identifiable {
        let id: String
        let titleKey: String
        let symbol: String
    }

    static let sections: [SidebarSection] = [
        SidebarSection(id: "Log", titleKey: "Log", symbol: "list.bullet"),
        SidebarSection(id: "Insights", titleKey: "Insights", symbol: "chart.bar.fill"),
        SidebarSection(id: "Budget", titleKey: "Budget", symbol: "chart.pie.fill"),
        SidebarSection(id: "Settings", titleKey: "Settings", symbol: "gearshape.fill")
    ]
}
