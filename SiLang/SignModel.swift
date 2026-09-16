//
//  SignModel.swift
//  SiLang
//
//  Created by Gian Denggan Benjamin on 15/09/26.
//

import Foundation

/// Represents a detected sign and its meaning.
struct SignModel: Codable {
    let sign: String
    let meaning: String
}
