//
//  MathUtils.swift
//  HexagonApp
//
//  Created by Duncan Champney on 3/30/26.
//
import Foundation
import MetalKit
import simd

public func centerPoint(trianglePoints: TrianglePoints) -> SIMD2<Float> {
    let x = (trianglePoints.point1.x + trianglePoints.point2.x + trianglePoints.point3.x) / 3
    let y = (trianglePoints.point1.y + trianglePoints.point2.y + trianglePoints.point3.y) / 3
    return SIMD2<Float>(x, y)
}

// Utility closure to rotate a 2D point around a center in 2D
public func rotateTriangle(trianglePoints: TrianglePoints, angle: Float, aroundCenter center: SIMD2<Float>) -> TrianglePoints {
    func rotate(point: SIMD2<Float>, angle: Float, center: SIMD2<Float>) -> SIMD2<Float> {
        let translated = point - center
        let cosA = cos(angle)
        let sinA = sin(angle)
        let rotated = SIMD2<Float>(
            x: translated.x * cosA - translated.y * sinA,
            y: translated.x * sinA + translated.y * cosA
        )
        return rotated + center
    }
    let center2D = SIMD2<Float>(center.x, center.y)
    let point1 = rotate(point: trianglePoints.point1, angle: angle, center: center2D)
    let point2 = rotate(point: trianglePoints.point2, angle: angle, center: center2D)
    let point3 = rotate(point: trianglePoints.point3, angle: angle, center: center2D)
    return TrianglePoints(point1: point1, point2: point2, point3: point3)
}

