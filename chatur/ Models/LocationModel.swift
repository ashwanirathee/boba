//
//  LocationModel.swift
//  chatur
//
//  Created by ashwani on 12/07/25.
//

import CoreLocation

struct Location: Equatable{
    var latitude: Double
    var longitude: Double
    
    static let zero = Location(latitude: 0, longitude: 0)

     var coordinate: CLLocationCoordinate2D {
         CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
     }

     var isValid: Bool {
         latitude != 0.0 && longitude != 0.0
     }
    
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
