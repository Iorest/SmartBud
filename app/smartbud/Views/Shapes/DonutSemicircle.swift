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
            path.addArc(center: center, radius: radius, startAngle: Angle(radians: CGFloat.pi + cornerAngle), endAngle: endAngle, clockwise: false)
        }

        var secondControlPoint: CGPoint
        var secondControlPointTo: CGPoint
        var thirdControlPointFrom: CGPoint
        var thirdControlPoint: CGPoint
        var thirdControlPointTo: CGPoint

        if percent > 0.5 {
            let sweep = CGFloat(180 * (1 - percent)).toRadians()
            let sweepCosine = cos(sweep)
            let sweepSine = sin(sweep)
            secondControlPoint = CGPoint(x: radius + radius * sweepCosine,
                                         y: radius - radius * sweepSine)
            secondControlPointTo = CGPoint(x: radius + weirdLength * sweepCosine,
                                           y: radius - weirdLength * sweepSine)
            thirdControlPointFrom = CGPoint(x: radius + outerLeg * sweepCosine,
                                            y: radius - outerLeg * sweepSine)
            thirdControlPoint = CGPoint(x: radius + innerRadius * sweepCosine,
                                        y: radius - innerRadius * sweepSine)
            thirdControlPointTo = CGPoint(x: radius + innerRadius * cos(stupidAngle + sweep),
                                          y: radius - innerRadius * sin(stupidAngle + sweep))

        } else if percent < 0.5 {
            let sweep = CGFloat(180 * percent).toRadians()
            let sweepCosine = cos(sweep)
            let sweepSine = sin(sweep)
            secondControlPoint = CGPoint(x: radius - radius * sweepCosine,
                                         y: radius - radius * sweepSine)
            secondControlPointTo = CGPoint(x: radius - weirdLength * sweepCosine,
                                           y: radius - weirdLength * sweepSine)
            thirdControlPointFrom = CGPoint(x: radius - outerLeg * sweepCosine,
                                            y: radius - outerLeg * sweepSine)
            thirdControlPoint = CGPoint(x: radius - innerRadius * sweepCosine,
                                        y: radius - innerRadius * sweepSine)
            thirdControlPointTo = CGPoint(x: radius - innerRadius * cos(-stupidAngle + sweep),
                                          y: radius - innerRadius * sin(-stupidAngle + sweep))
        } else {
            secondControlPoint = CGPoint(x: rect.midX, y: rect.minY)
            secondControlPointTo = CGPoint(x: rect.midX, y: radius - weirdLength)
            thirdControlPointFrom = CGPoint(x: rect.midX, y: radius - (innerRadius + weirderLength))
            thirdControlPoint = CGPoint(x: rect.midX, y: width)
            thirdControlPointTo = CGPoint(x: radius - innerRadius * cos(CGFloat.pi / 2 - stupidAngle), y: radius - innerRadius * sin(CGFloat.pi / 2 - stupidAngle))
        }

        path.addQuadCurve(to: secondControlPointTo, control: secondControlPoint)

        path.addLine(to: thirdControlPointFrom)
        path.addQuadCurve(to: thirdControlPointTo, control: thirdControlPoint)

        if (endAngle - Angle(radians: stupidAngle)) > Angle(radians: CGFloat.pi + dumbassAngle) {
            path.addArc(center: center, radius: innerRadius, startAngle: endAngle - Angle(radians: stupidAngle), endAngle: Angle(radians: CGFloat.pi + dumbassAngle), clockwise: true)
        }

        let fourthControlPoint = CGPoint(x: width, y: rect.maxY)
        let fourthControlPointTo = CGPoint(x: width - weirderLength, y: rect.maxY)

        path.addQuadCurve(to: fourthControlPointTo, control: fourthControlPoint)

        path.closeSubpath()
        return path
    }
}
