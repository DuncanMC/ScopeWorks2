//
//  MathUtils.swift
//  HexagonApp
//
//  Created by Duncan Champney on 3/30/26.
//
import Foundation
import MetalKit
import simd


extension FloatingPoint {
  /// Allows mapping between reverse ranges, which are illegal to construct (e.g. `10..<0`).
  func interpolated(
    fromLowerBound: Self,
    fromUpperBound: Self,
    toLowerBound: Self,
    toUpperBound: Self) -> Self
  {
    let positionInRange = (self - fromLowerBound) / (fromUpperBound - fromLowerBound)
    return (positionInRange * (toUpperBound - toLowerBound)) + toLowerBound
  }

  func interpolated(from: ClosedRange<Self>, to: ClosedRange<Self>) -> Self {
    interpolated(
      fromLowerBound: from.lowerBound,
      fromUpperBound: from.upperBound,
      toLowerBound: to.lowerBound,
      toUpperBound: to.upperBound)
  }
}

public func distanceBetween(p1:  CGPoint, p2: CGPoint) -> CGFloat {
    let deltaX = p1.x - p2.x
    let deltaY = p1.y - p2.y
    return sqrt(deltaX * deltaX + deltaY * deltaY)
}


public func distanceBetween(p1:  SIMD2<Float>, p2: SIMD2<Float>) -> Float {
    let deltaX = p1.x - p2.x
    let deltaY = p1.y - p2.y
    return sqrt(deltaX * deltaX + deltaY * deltaY)
}
 
func remap(sourceMin: Float, sourceMax: Float, destMin: Float, destMax: Float, t: Float) -> Float {
    let f = (t - sourceMin) / (sourceMax - sourceMin)
    return simd_mix(destMin, destMax, f)
}

public func midpoint(p1:  SIMD2<Float>, p2: SIMD2<Float>) -> SIMD2<Float> {
    return SIMD2<Float>(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
}

public func centerCGPoint(triangleCGPoints: TriangleCGPoints) -> CGPoint {
    let x = (triangleCGPoints.point1.x + triangleCGPoints.point2.x + triangleCGPoints.point3.x) / 3
    let y = (triangleCGPoints.point1.y + triangleCGPoints.point2.y + triangleCGPoints.point3.y) / 3
    return CGPoint(x: x, y: y)
}

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

extension simd_float2 {
    
    public init(_ cgPoint: CGPoint) {
        self.init(x: Float(cgPoint.x), y: Float(cgPoint.y))
    }
    public var myDescription: String {
        return "(\(self[0]), \(self[1]))"
    }
}

// MARK: - trasformation matrix utilities

func makeTranslationMatrix(tx: Float, ty: Float) -> simd_float3x3 {
    
    var matrix = matrix_identity_float3x3
    
    matrix[0, 2] = tx
    matrix[1, 2] = ty
    
    return matrix

//    let rows = [
//        simd_float3(     1,      0,     0),
//        simd_float3(     0,      1,     0),
//        simd_float3(     tx,      ty,      1)
//    ]
//    
//    return float3x3(rows: rows)

//    var matrix = matrix_identity_float3x3
//
    //This code from the sample is wrong (rows and columns are reversed)
//    matrix[2, 0] = tx
//    matrix[2, 1] = ty
//    
//    return matrix
}

func makeRotationMatrix(angle: Float) -> simd_float3x3 {
    let rows = [
        simd_float3(cos(angle), -sin(angle), 0),
        simd_float3(sin(angle), cos(angle), 0),
        simd_float3(0,          0,          1)
    ]
    
    return float3x3(rows: rows)
}

func makeScaleMatrix(xScale: Float, yScale: Float) -> simd_float3x3 {
    let rows = [
        simd_float3(xScale,      0, 0),
        simd_float3(     0, yScale, 0),
        simd_float3(     0,      0, 1)
    ]
    
    return float3x3(rows: rows)
}
