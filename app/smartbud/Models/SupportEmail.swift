//
//  SupportEmail.swift
//  Bonsai
//
//  Created by Iorest on 8/7/22.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
struct SupportEmail {
    let toAddress: String
    let subject: String
    var body: String { """
        Application Name: \(Bundle.main.displayName) |
        OS: \(DeviceInfo.systemVersion) |
        Device Model: \(DeviceInfo.modelName) |
        App Version: \(Bundle.main.appVersion) |
        App Build: \(Bundle.main.appBuild) |
    --------------------------------------
    """
    }

    func send(openURL: OpenURLAction) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "mailto:\(toAddress)?subject=\(encodedSubject)&body=\(encodedBody)"
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}
