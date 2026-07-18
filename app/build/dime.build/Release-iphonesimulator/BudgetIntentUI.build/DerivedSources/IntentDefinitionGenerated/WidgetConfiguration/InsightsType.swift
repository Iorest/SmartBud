//
// InsightsType.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum InsightsType: Int {
    case `unknown` = 0
    case `net` = 1
    case `income` = 2
    case `expense` = 3
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(InsightsTypeResolutionResult)
public class InsightsTypeResolutionResult: INEnumResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given InsightsType. The resolvedValue can be different than the original InsightsType. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedInsightsType:)
    public class func success(with resolvedValue: InsightsType) -> Self {
        return __success(withResolvedValue: resolvedValue.rawValue)
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithInsightsTypeToConfirm:)
    public class func confirmationRequired(with valueToConfirm: InsightsType) -> Self {
        return __confirmationRequiredWithValue(toConfirm: valueToConfirm.rawValue)
    }
}

#endif
