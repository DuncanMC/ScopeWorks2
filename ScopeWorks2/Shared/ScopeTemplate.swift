//
//  ScopeTemplate.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/2/26.
//
import Foundation

public enum ElementType: Int, Codable {
    case polygon
    case eightWay
}

struct ScopeElement: Codable {
    let type: ElementType
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Float

    enum CodingKeys: String, CodingKey {
        case type, centerX, centerY, radius, startAngle
    }

    init(type: ElementType, center: CGPoint, radius: CGFloat, startAngle: Float) {
        self.type = type
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ElementType.self, forKey: .type)
        let x = try container.decode(Double.self, forKey: .centerX)
        let y = try container.decode(Double.self, forKey: .centerY)
        center = CGPoint(x: x, y: y)
        radius = CGFloat(try container.decode(Double.self, forKey: .radius))
        startAngle = try container.decode(Float.self, forKey: .startAngle)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(Double(center.x), forKey: .centerX)
        try container.encode(Double(center.y), forKey: .centerY)
        try container.encode(Double(radius), forKey: .radius)
        try container.encode(startAngle, forKey: .startAngle)
    }
}

struct ScopeTemplate: Codable {
    let index: Int
    let name: String
    let description: String
    let elements: [ScopeElement]
    let modifiedDate: Date
    let isPolygonType: Bool
}
