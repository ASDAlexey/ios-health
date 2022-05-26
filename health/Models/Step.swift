//
//  File.swift
//  health
//
//  Created by Alexey on 26.05.2022.
//

import Foundation

struct Step: Identifiable {
    let id = UUID()
    let count: Int
    let date: Date
}
