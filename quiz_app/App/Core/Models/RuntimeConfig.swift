//
//  RuntimeConfig.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation

/// Wrapper minimale per accedere a runtime a info di configurazione
struct RuntimeConfig: Codable {
    let scales_questions: [Int]
    let scales_category: [Int]

    /// Fallback se i campi mancano nel JSON
    static let `default` = RuntimeConfig(
        scales_questions: [10, 20, 50, Int.max],
        scales_category: [5, 10, 20, 50, Int.max]
    )

    /// Utility per etichettare l'opzione "tutte"
    func displayLabel(for value: Int) -> String {
        if value == Int.max { return "Tutte" }
        return "\(value)"
    }
}
