//
//  HeartRate.swift
//  health
//
//  Created by Alexey on 27.05.2022.
//

import Foundation

struct HeartRate: Identifiable {
    let id = UUID()
    let min: Int
    let max: Int
    let avg: Int
}
