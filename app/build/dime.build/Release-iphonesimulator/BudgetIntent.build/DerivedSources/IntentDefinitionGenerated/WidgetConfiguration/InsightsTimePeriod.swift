//
// InsightsTimePeriod.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum InsightsTimePeriod: Int {
    case `unknown` = 0
    case `week` = 1
    case `month` = 2
    case `year` = 3
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(InsightsTimePeriodResolutionResult)
public class InsightsTimePeriodResolutionResult: INEnumResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given InsightsTimePeriod. The resolvedValue can be different than the original InsightsTimePeriod. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedInsightsTimePeriod:)
    public class func success(with resolvedValue: InsightsTimePeriod) -> Self {
        return __success(withResolvedValue: resolvedValue.rawValue)
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithInsightsTimePeriodToConfirm:)
    public class func confirmationRequired(with valueToConfirm: InsightsTimePeriod) -> Self {
        return __confirmationRequiredWithValue(toConfirm: valueToConfirm.rawValue)
    }
}

#endif
