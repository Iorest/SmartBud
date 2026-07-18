//
// TimePeriod.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum TimePeriod: Int {
    case `unknown` = 0
    case `day` = 1
    case `week` = 2
    case `month` = 3
    case `year` = 4
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(TimePeriodResolutionResult)
public class TimePeriodResolutionResult: INEnumResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given TimePeriod. The resolvedValue can be different than the original TimePeriod. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedTimePeriod:)
    public class func success(with resolvedValue: TimePeriod) -> Self {
        return __success(withResolvedValue: resolvedValue.rawValue)
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithTimePeriodToConfirm:)
    public class func confirmationRequired(with valueToConfirm: TimePeriod) -> Self {
        return __confirmationRequiredWithValue(toConfirm: valueToConfirm.rawValue)
    }
}

#endif
