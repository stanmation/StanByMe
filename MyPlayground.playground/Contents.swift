//: Playground - noun: a place where people can play

import CoreLocation


let coordinate0 = CLLocation(latitude: 5.0, longitude: 5.0)
let coordinate1 = CLLocation(latitude: 5.0, longitude: 3.0)

let distanceInMeters = coordinate0.distance(from: coordinate1)

let distanceInKm = distanceInMeters/1000
