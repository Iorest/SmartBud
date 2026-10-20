//
//  EmailExtensions.swift
//  smartbud
//
//  Created by Iorest on 8/7/22.
//
//  UIDevice + Bundle helpers specific to the email / support flow:
//    * `UIDevice.DeviceModel` decodes the iPhone/iPad model table
//      bundled at `DeviceModels.json`.
//    * `UIDevice.modelName` resolves the current device's model
//      identifier (e.g. "iPhone16,1") to a human-readable name
//      ("iPhone 15 Pro") using that table.
//    * `Bundle.decode<T>(…)` is a tiny JSON loader used by the
//      support email body.
//
//  Version / build / display-name accessors live in `AppVersion.swift`.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

#if !os(macOS)
extension UIDevice {
    struct DeviceModel: Decodable {
        let identifier: String
        let model: String
        static var all: [DeviceModel] {
            Bundle.main.decode([DeviceModel].self, from: "DeviceModels.json") ?? []
        }
    }

    var modelName: String {
        #if targetEnvironment(simulator)
            let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "simulator"
        #else
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
        #endif
        return DeviceModel.all.first { $0.identifier == identifier }?.model ?? identifier
    }
}
#endif

/// Cross-platform replacement for the two `UIDevice` facts the support email
/// needs. macOS has no `UIDevice`; the hardware model comes from `hw.model`.
/// `UIDevice.current` is main-actor isolated, and every caller
/// (`SupportEmail`) already runs there.
@MainActor
enum DeviceInfo {
    static var systemVersion: String {
        #if os(macOS)
        ProcessInfo.processInfo.operatingSystemVersionString
        #else
        UIDevice.current.systemVersion
        #endif
    }

    static var modelName: String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let bytes = model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? "Mac"
        #else
        UIDevice.current.modelName
        #endif
    }
}

extension Bundle {
    /// Returns `nil` when the resource is missing or malformed instead of
    /// trapping: the only caller (device model lookup for support mail) can
    /// fall back to the raw hardware identifier.
    func decode<T: Decodable>(_: T.Type,
                              from file: String,
                              dateDecodingStategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                              keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) -> T? {
        guard let url = url(forResource: file, withExtension: nil),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        return try? decoder.decode(T.self, from: data)
    }
}
