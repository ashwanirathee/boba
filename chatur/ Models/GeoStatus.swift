//
//  GeoStatus.swift
//  chatur
//
//  Created by ashwani on 20/08/25.
//


import ARKit

struct GeoStatus: Equatable {
    var state: ARGeoTrackingStatus.State = .notAvailable
    var accuracy: ARGeoTrackingStatus.Accuracy = .undetermined
    var actions: ARGeoTrackingStatus.StateReason = .none
}
