//
//  PhotoRecordModel.swift
//  chatur
//
//  Created by ashwani on 14/08/25.
//

import Foundation
import SQLite3

struct PhotoRecord: Identifiable {
    let id: Int64
    let timestamp: Int64   // seconds since 1970
    let latitude: Double
    let longitude: Double
    let filePath: String

}
