//
//  GeoJSON.swift
//  GeoJSON
//
//  Created by Adolfo Martinelli on 10/4/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import Foundation
import CoreLocation

public typealias GeoJSONDictionary = [NSObject: AnyObject]

public protocol GeoJSONConvertible {
	init?(dictionary: GeoJSONDictionary)
	func geoJSONRepresentation() -> GeoJSONDictionary
}

public protocol CoordinateConvertible {
	associatedtype CoordinateRepresentationType
	init?(coordinates: CoordinateRepresentationType)
	func coordinateRepresentation() -> CoordinateRepresentationType
}

public protocol GeometryConvertible {
	associatedtype GeometryType
	var geometry: GeometryType { get set }
	init()
}

extension GeometryConvertible {
	public init(geometry: GeometryType) {
		self.init()
		self.geometry = geometry
	}
}

public protocol Feature: GeoJSONConvertible, CoordinateConvertible, GeometryConvertible {}

extension Feature {
	public init?(dictionary: GeoJSONDictionary) {
		guard let coordinates = dictionary["geometry"]?["coordinates"] as? CoordinateRepresentationType else { return nil }
		self.init(coordinates: coordinates)
	}
}

public class Point: Feature {
	
	public typealias GeometryType = CLLocationCoordinate2D!
	public typealias CoordinateRepresentationType = [Double]
	
	public var geometry: CLLocationCoordinate2D!
	
	public required init() {}
	
	public required init?(coordinates: CoordinateRepresentationType) {
		guard let position = CLLocationCoordinate2D(coordinates: coordinates) else { return nil }
		geometry = position
	}
	
	public func coordinateRepresentation() -> CoordinateRepresentationType {
		return geometry.geoJSONRepresentation
	}
}

public class LineString: Feature {
	
	public typealias GeometryType = [CLLocationCoordinate2D]!
	public typealias CoordinateRepresentationType = [[Double]]
	
	public var geometry: [CLLocationCoordinate2D]!

	public required init() {}

	public required init?(coordinates: CoordinateRepresentationType) {
		guard let positions = coordinates.map(CLLocationCoordinate2D.init) as? [CLLocationCoordinate2D]
		else { return nil }
		geometry = positions
	}
	
	public func coordinateRepresentation() -> CoordinateRepresentationType {
		return geometry.map { $0.geoJSONRepresentation }
	}
}

public class Polygon: Feature {
	
	public typealias GeometryType = [[CLLocationCoordinate2D]]!
	public typealias CoordinateRepresentationType = [[[Double]]]
	
	public var geometry: [[CLLocationCoordinate2D]]!

	public required init() {}

	public required init?(coordinates: CoordinateRepresentationType) {
		guard let linearRings = coordinates.map({ $0.flatMap(CLLocationCoordinate2D.init) }) as GeometryType? else { return nil }
		for linearRing in linearRings {
			guard linearRing.first == linearRing.last else { return nil }
		}
		self.geometry = linearRings
	}
	
	public func coordinateRepresentation() -> CoordinateRepresentationType {
		return geometry.map { $0.map { $0.geoJSONRepresentation } }
	}
}

public typealias MultiPoint = Multi<Point>

public typealias MultiLineString = Multi<LineString>

public typealias MultiPolygon = Multi<Polygon>

public class Multi<FeatureType: Feature> {
	
	public var features = [FeatureType]()
	
	public typealias GeometryType = [FeatureType.GeometryType]
	public typealias CoordinateRepresentationType = [FeatureType.CoordinateRepresentationType]
	
	public var geometry: GeometryType!
	
	public required init() {}
	
	public required init?(coordinates: CoordinateRepresentationType) {
		let features = coordinates.flatMap { (coords: FeatureType.CoordinateRepresentationType) in
			FeatureType(coordinates: coords)
		}
		self.features = features
		self.geometry = features.map { $0.geometry }
	}
	
	public var coordinateRepresentation: CoordinateRepresentationType {
		return features.map { $0.coordinateRepresentation() }
	}
	
}

public class FeatureCollection: GeoJSONConvertible {
	
	public var features: [GeoJSONConvertible]
	
	public required init(features: [GeoJSONConvertible]) {
		self.features = features
	}
	
	public required init?(dictionary: GeoJSONDictionary) {

		let geoJSONfeatures = dictionary["features"] as? [GeoJSONDictionary]

		self.features = geoJSONfeatures?
			.flatMap { feature in
				let type = feature["geometry"]?["type"] as! String
				switch type {
				case String(Point):       return Point(dictionary: feature)
				case String(Polygon):     return Polygon(dictionary: feature)
				case String(LineString):  return LineString(dictionary: feature)
				default:
					print("GeoJSON type", type, "not implemented!")
					return nil
				}
		} ?? []
	}
	
	public func geoJSONRepresentation() -> GeoJSONDictionary {
		return [
			"type": "FeatureCollection",
			"features": features.map { $0.geoJSONRepresentation() },
			"properties": NSNull()
		]
	}
}

extension Feature {
	
	public func geoJSONRepresentation() -> GeoJSONDictionary {
		return [
			"type": "Feature",
			"geometry": [
				"type": String(self.dynamicType),
				"coordinates": coordinateRepresentation() as! AnyObject,
				"properties": NSNull()
			],
			"properties": NSNull()
		]
	}
}

extension CLLocationCoordinate2D: Equatable {
	
	init?(coordinates: [Double]) {
		guard coordinates.count == 2 else { return nil }
		longitude = coordinates[0]
		latitude = coordinates[1]
	}
	
	var geoJSONRepresentation: [Double] {
		return [longitude, latitude]
	}
}

public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
	return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

public func +(lhs: FeatureCollection, rhs: FeatureCollection) -> FeatureCollection {
	return FeatureCollection(features: lhs.features+rhs.features)
}
