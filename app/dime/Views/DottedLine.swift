//
//  DottedLine.swift
//  dime
//
//  One-pixel-wide vertical dotted line. Used by `LogView` to separate the
//  income / spent totals in the insights card. Pulled out of the old
//  `LineGraph.swift` so it can be reused without dragging the chart in.
//

import SwiftUI

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        return path
    }
}
