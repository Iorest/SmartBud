//
//  DonutSemicircle.swift
//  smartbud
//
//  Created by Iorest on 24/10/23.
//

import Foundation
import SwiftUI

extension CGFloat {
    func toRadians() -> CGFloat {
        return self * CGFloat(Double.pi) / 180.0
    }
}

struct DonutSemicircle: Shape {
    var percent: Double

    var animatableData: Double {
        get { percent }
        set { percent = newValue }
    }

    var cornerRadius: CGFloat
    var width: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let cornerAngle = asin(cornerRadius / (radius - cornerRadius))
        let endAngle = Angle(degrees: 180 + (180 * percent)) - Angle(radians: cornerAngle)
        let weirdLength = sqrt(((radius - cornerRadius) * (radius - cornerRadius)) - (cornerRadius * cornerRadius))
        let weirderLength = radius - weirdLength
        let innerRadius = radius - width
        let innerLeg = innerRadius + cornerRadius
        let outerLeg = innerRadius + weirderLength
        let stupidAngle = acos((innerLeg * innerLeg + outerLeg * outerLeg - cornerRadius * cornerRadius)
                               / (2 * innerLeg * outerLeg))
        let dumbassAngle = asin(cornerRadius / (innerRadius + cornerRadius))

        var path = Path()
        path.move(to: CGPoint(x: radius - weirdLength, y: rect.maxY))
//        path.move(to:CGPoint(x: rect.width * 0.3, y: rect.maxY))

        let firstControlPoint = CGPoint(x: radius - radius * cos(cornerAngle), y: rect.maxY - radius * sin(cornerAngle))

        path.addQuadCurve(to: firstControlPoint, control: CGPoint(x: 0, y: rect.maxY))

        if endAngle > Angle(radians: CGFloat.pi + cornerAngle) {
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: CGFloat.pi + cornerAngle),
                endAngle: endAngle,
                clockwise: false
            )
        }

        let geometry = Geometry(radius: radius, weirdLength: weirdLength,
                                weirderLength: weirderLength, innerRadius: innerRadius,
                                outerLeg: outerLeg, stupidAngle: stupidAngle, rect: rect)
        let points = controlPoints(geometry)

        path.addQuadCurve(to: points.secondTo, control: points.second)

        path.addLine(to: points.thirdFrom)
        path.addQuadCurve(to: points.thirdTo, control: points.third)

        if (endAngle - Angle(radians: stupidAngle)) > Angle(radians: CGFloat.pi + dumbassAngle) {
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: endAngle - Angle(radians: stupidAngle),
                endAngle: Angle(radians: CGFloat.pi + dumbassAngle),
                clockwise: true
            )
        }

        let fourthControlPoint = CGPoint(x: width, y: rect.maxY)
        let fourthControlPointTo = CGPoint(x: width - weirderLength, y: rect.maxY)

        path.addQuadCurve(to: fourthControlPointTo, control: fourthControlPoint)

        path.closeSubpath()
        return path
    }

    /// Curve control points for the filled arc; see `path(in:)` for the maths.
    private struct ControlPoints {
        let second: CGPoint
        let secondTo: CGPoint
        let thirdFrom: CGPoint
        let third: CGPoint
        let thirdTo: CGPoint
    }

    private struct Geometry {
        let radius: CGFloat
        let weirdLength: CGFloat
        let weirderLength: CGFloat
        let innerRadius: CGFloat
        let outerLeg: CGFloat
        let stupidAngle: CGFloat
        let rect: CGRect
    }

    private func controlPoints(_ geometry: Geometry) -> ControlPoints {
        let radius = geometry.radius
        let weirdLength = geometry.weirdLength
        let innerRadius = geometry.innerRadius
        let outerLeg = geometry.outerLeg
        let stupidAngle = geometry.stupidAngle

        if percent > 0.5 {
            let sweep = CGFloat(180 * (1 - percent)).toRadians()
            let cosine = cos(sweep)
            let sine = sin(sweep)
            return ControlPoints(
                second: CGPoint(x: radius + radius * cosine, y: radius - radius * sine),
                secondTo: CGPoint(x: radius + weirdLength * cosine, y: radius - weirdLength * sine),
                thirdFrom: CGPoint(x: radius + outerLeg * cosine, y: radius - outerLeg * sine),
                third: CGPoint(x: radius + innerRadius * cosine, y: radius - innerRadius * sine),
                thirdTo: CGPoint(x: radius + innerRadius * cos(stupidAngle + sweep),
                                 y: radius - innerRadius * sin(stupidAngle + sweep))
            )
        }

        if percent < 0.5 {
            let sweep = CGFloat(180 * percent).toRadians()
            let cosine = cos(sweep)
            let sine = sin(sweep)
            return ControlPoints(
                second: CGPoint(x: radius - radius * cosine, y: radius - radius * sine),
                secondTo: CGPoint(x: radius - weirdLength * cosine, y: radius - weirdLength * sine),
                thirdFrom: CGPoint(x: radius - outerLeg * cosine, y: radius - outerLeg * sine),
                third: CGPoint(x: radius - innerRadius * cosine, y: radius - innerRadius * sine),
                thirdTo: CGPoint(x: radius - innerRadius * cos(-stupidAngle + sweep),
                                 y: radius - innerRadius * sin(-stupidAngle + sweep))
            )
        }

        return midpointPoints(geometry)
    }

    /// Exactly half a circle: the arc ends at the top centre.
    private func midpointPoints(_ geometry: Geometry) -> ControlPoints {
        let radius = geometry.radius
        let innerRadius = geometry.innerRadius
        let rect = geometry.rect
        return ControlPoints(
            second: CGPoint(x: rect.midX, y: rect.minY),
            secondTo: CGPoint(x: rect.midX, y: radius - geometry.weirdLength),
            thirdFrom: CGPoint(x: rect.midX, y: radius - (innerRadius + geometry.weirderLength)),
            third: CGPoint(x: rect.midX, y: width),
            thirdTo: CGPoint(x: radius - innerRadius * cos(CGFloat.pi / 2 - geometry.stupidAngle),
                             y: radius - innerRadius * sin(CGFloat.pi / 2 - geometry.stupidAngle))
        )
    }
}
