import MetalKit
import simd

#if os(iOS)
import UIKit
#endif

class SourceImageRenderer: NSObject, MTKViewDelegate {
    
    func logPoints(imagePoints: TrianglePoints) {
        print("TrianglePoints:")
        print("   trianglePoints.point1 = \(scopeState.trianglePoints.point1.myDescription)")
        print("   trianglePoints.point2 = \(scopeState.trianglePoints.point2.myDescription)")
        print("   trianglePoints.point2 = \(scopeState.trianglePoints.point3.myDescription)")
        print("ImagePoints:")
        print("   imagePoints.point1 = \(imagePoints.point1.myDescription)")
        print("   imagePoints.point2 = \(imagePoints.point2.myDescription)")
        print("   imagePoints.point2 = \(imagePoints.point3.myDescription)")

    }
    var sampleCount: Int = 1

    var scale: Float = 1.0
    static var logPoints: Bool = false
//    static var indexToDraw: Int? = nil
    weak var mtkView: MTKView?
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipeline: MTLRenderPipelineState!

    
    var scopeState: ScopeState
    // Track current drawable size for orientation handling
    private(set) var drawableSize: CGSize = .zero
    
    struct Uniforms {
        let color: simd_float4      //Only used when drawing outlines
        let drawWithTetxure: Bool   // Tells shader to draw with texture rather than color
        let drawTextureTriangles: Bool  
        let textureTriangle: TrianglePoints
        let texAspect: Float
        let orthoMatrix: float4x4
        let flipTextureY: Bool
    }
//    weak var imageData: Data?

#if os(iOS)
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        super.init()
        device = MTLCreateSystemDefaultDevice()
        if device.supportsTextureSampleCount(4) {
            sampleCount = 4
        } else if device.supportsTextureSampleCount(2) {
            sampleCount = 2
        }
        commandQueue = device.makeCommandQueue()
        makePipeline()
    }
#elseif os(macOS)
        init(scopeState: ScopeState) {
            self.scopeState = scopeState
            super.init()
            device = MTLCreateSystemDefaultDevice()
            if device.supportsTextureSampleCount(4) {
                sampleCount = 4
            } else if device.supportsTextureSampleCount(2) {
                sampleCount = 2
            }
            commandQueue = device.makeCommandQueue()
            makePipeline()
//            loadTexture()
        }
#endif

    func calcTrianglePoints()
    -> TrianglePoints {
        guard scopeState.selectedImageData != nil else {
            return (TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint))
        }

        let point1 = SIMD2<Float>(0.4, 0.25)
        let point2 = SIMD2<Float>(0.6, 0.25)
        let base =  point2[0] - point1[0]
        let angle = .pi / 3.0
        let deltaY = Float(sin(angle)) * base
        let deltaX = Float(cos(angle)) * base
        let point3 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)
        return TrianglePoints(point1: point1, point2: point2, point3: point3)
    }
    

    func makePipeline() {
        let library = device.makeDefaultLibrary()
        let pipelineDesc = MTLRenderPipelineDescriptor()

        pipelineDesc.vertexFunction = library?.makeFunction(name: "vertex_main")
        pipelineDesc.fragmentFunction = library?.makeFunction(name: "fragment_main")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for transparent drawing
        pipelineDesc.rasterSampleCount = sampleCount // xxx
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        pipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }

    func updateImageData() {
    }
    
    func draw(in view: MTKView) {
        
        enum ArrowHeadDirection {
            case down
            case left
        }
        
        
        //        let width = view.drawableSize.width
        let height = view.drawableSize.height
        guard height != 0 else {
            print("Window height is zero!")
            return
        }
        
        guard let drawable = view.currentDrawable else {
            print("[ScopeRenderer] currentDrawable is nil")
            return
        }
        guard let descriptor = view.currentRenderPassDescriptor else {
            print("[ScopeRenderer] currentRenderPassDescriptor is nil")
            return
        }
        guard let pipeline = pipeline else {
            print("[ScopeRenderer] pipeline is nil")
            return
        }
        guard let texture = scopeState.texture else {
            return
        }
        
#if os(macOS)
        scale = Float(mtkView?.window?.screen?.backingScaleFactor ?? 1.0)
#else
        scale = Float(mtkView?.contentScaleFactor ?? 1)
#endif
        
        let texWidth = Float(texture.width)
        let texHeight = Float(texture.height)
        let texAspect = texWidth / texHeight
        
        // Model-View-Projection matrix example
        let orthoMatrix = matrix_identity_float4x4
        
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let colorComponents = scopeState.backgroundColor.components()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: colorComponents[0],
            green: colorComponents[1],
            blue: colorComponents[2],
            alpha: colorComponents[3])
        
        descriptor.colorAttachments[0].loadAction =  MTLLoadAction.clear
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        var verts: [simd_float2]
        
        let p1 = simd_float2(x: -1, y:  1)
        let p2 = simd_float2(x:  1, y:  1)
        let p3 = simd_float2(x:  1, y: -1)
        let p4 = simd_float2(x: -1, y: -1)
        
        verts = [p1, p2, p3]
        
        encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
        
        var uniforms: Uniforms = Uniforms(
            color: simd_float4(1, 1, 1, 1),
            drawWithTetxure: true,
            drawTextureTriangles: false,
            textureTriangle: scopeState.trianglePoints,
            texAspect: 1,
            orthoMatrix: orthoMatrix,
            flipTextureY: scopeState.flipTextureY
        )
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        verts = [p1, p3, p4]
        
        encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        let imagePoints: TrianglePoints = TrianglePoints(
            point1: simd_float2(x: scopeState.trianglePoints.point1.x * 2 / scopeState.texAspect - 1, y: scopeState.trianglePoints.point1.y * 2 - 1),
            point2: simd_float2(x: scopeState.trianglePoints.point2.x * 2 / scopeState.texAspect - 1, y: scopeState.trianglePoints.point2.y * 2 - 1),
            point3: simd_float2(x: scopeState.trianglePoints.point3.x * 2 / scopeState.texAspect - 1, y: scopeState.trianglePoints.point3.y * 2 - 1)
        )
        drawThickLine(
            p1: imagePoints.point1 , p2: imagePoints.point2,
            color: black,
            thickness:  6.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        drawThickLine(
            p1: imagePoints.point2, p2: imagePoints  .point3,
            color: black,
            thickness:  6.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        drawThickLine(
            p1: imagePoints.point3, p2: imagePoints.point1,
            color: black,
            thickness:  6.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        drawThickLine(
            p1: imagePoints.point1 , p2: imagePoints.point2,
            color: white,
            thickness:  2.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        drawThickLine(
            p1: imagePoints.point2, p2: imagePoints.point3,
            color: white,
            thickness:  2.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        drawThickLine(
            p1: imagePoints.point3, p2: imagePoints.point1,
            color: white,
            thickness:  3.0 / Float(drawableSize.width),
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        let outsideWidth: Float = 10
        let insideWidth: Float = 8
        
        // Draw the center point of the polygon as a "donut" shape so it stands out.
        drawCircle(center: imagePoints.point1, color: black, orthoMatrix: orthoMatrix, texAspect: texAspect, radius: 12, lineThickness: 10)
        drawCircle(center: imagePoints.point1, color: yellow, orthoMatrix: orthoMatrix, texAspect: texAspect, radius: 12, lineThickness: 4)
        drawSquare(center: imagePoints.point2, color: black, width: outsideWidth, orthoMatrix: orthoMatrix, texAspect: texAspect)
        drawSquare(center: imagePoints.point2, color: yellow, width: insideWidth, orthoMatrix: orthoMatrix, texAspect: texAspect)
        
        drawSquare(center: imagePoints.point3, color: black, width: outsideWidth, orthoMatrix: orthoMatrix, texAspect: texAspect)
        drawSquare(center: imagePoints.point3, color: yellow, width: insideWidth, orthoMatrix: orthoMatrix, texAspect: texAspect)
        
        // MARK: - Draw the rotation center
        let rotationCenter = simd_float2(x:scopeState.rotationCenter.x * 2 / scopeState.texAspect - 1, y: scopeState.rotationCenter.y * 2 - 1)
        
        let rotationRadius: Float = 10
        
        // Outer rotation circle (black)
        drawCircle(
            center: rotationCenter,
            color: black,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect,
            radius: rotationRadius,
            lineThickness: 12)
        // inner rotation circle (white)
        drawCircle(
            center: rotationCenter,
            color: white,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect,
            radius: rotationRadius,
            lineThickness: 4)
        
        let arcRadius: Float = 27
        let arrowPoint1: simd_float2
        
        // Outer black arc
        drawArc(
            center: rotationCenter,
            color: black,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect,
            radius: arcRadius,
            startAngle: 0,
            endAngle: 90,
            steps: 10,
            lineThickness: 12)
        
        
        
        let arcOffset = arcRadius * scale / Float(view.drawableSize.width)
        
        let clockwise = scopeState.rotationSpeed < 0
        if clockwise {
            arrowPoint1 = simd_float2(x: rotationCenter.x + arcOffset, y: rotationCenter.y)
        } else {
            //counterclockwise
            arrowPoint1 = simd_float2(x: rotationCenter.x, y: rotationCenter.y + arcOffset)
        }
        
        // Outer black arrowhead
        let arrowHeadDirection: ArrowHeadDirection = clockwise ? .down : .left
        drawArrowHead(
            point: arrowPoint1,
            size: 16,
            direction: arrowHeadDirection,
            color: black,
            thickness: 8,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        
        // Inner white arc
        drawArc(
            center: rotationCenter,
            color: white,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect,
            radius: arcRadius,
            startAngle: 4,
            endAngle: arrowHeadDirection == .down ? 86 : 88,
            steps: 10,
            lineThickness: 4)
        
        // Inner white arrowhead lines
        drawArrowHead(
            point: arrowPoint1,
            size: 13,
            direction: arrowHeadDirection,
            color: white,
            thickness: 3,
            orthoMatrix: orthoMatrix,
            texAspect: texAspect)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // MARK: - nested drawing functions
        func drawCircle(
            center: simd_float2,
            color: SIMD4<Float>,
            orthoMatrix: float4x4,
            texAspect: Float,
            radius: Float,
            steps: Int = 24,
            lineThickness: Float,
        ) {
            drawArc(
                center: center,
                color: color,
                orthoMatrix: orthoMatrix,
                texAspect: texAspect,
                radius: radius,
                steps: steps,
                lineThickness: lineThickness)
        }
        
        func drawArc(
            center: simd_float2,
            color: SIMD4<Float>,
            orthoMatrix: float4x4,
            texAspect: Float,
            radius: Float,
            startAngle: Float = 0,
            endAngle: Float = 360.0,
            steps: Int = 24,
            lineThickness: Float,
            asDiamond: Bool = false) {
                
                let radius = radius * scale
                let widthPerPixel: Float = 1 / Float(view.drawableSize.width)
                let center: simd_float2 = simd_float2(x: center.x, y: center.y)
                let startAngleRadians = startAngle.degreesToRadians
                let arcDelta = endAngle.degreesToRadians - startAngleRadians
                let notFullCircle = startAngle != 0.0 || endAngle != 360.0
                
                var verticies = [simd_float2]()
                verticies.reserveCapacity(steps * 2)
                let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
                
                let loopSteps = notFullCircle ? steps - 1 : steps
                for step in 0 ..< loopSteps {
                    let angle = startAngleRadians + Float(step) / Float(steps) * arcDelta
                    let angle2 = startAngleRadians + Float((step+1) % steps) / Float(loopSteps) * arcDelta
                    
                    var deltaX = cos(angle) * widthPerPixel / scopeState.texAspect * (radius - lineThickness / 2)
                    var deltaY = sin(angle) * widthPerPixel * (radius - lineThickness / 2)
                    
                    let p1Inside = simd_float2(x: center.x + deltaX, y: center.y + deltaY)
                    
                    deltaX = cos(angle) * widthPerPixel / scopeState.texAspect * (radius + lineThickness / 2)
                    
                    deltaY = sin(angle) * widthPerPixel * (radius + lineThickness / 2)
                    let p1Outside = simd_float2(x: center.x + deltaX, y: center.y + deltaY)
                    
                    deltaX = cos(angle2) * widthPerPixel / scopeState.texAspect * (radius - lineThickness / 2)
                    deltaY = sin(angle2) * widthPerPixel * (radius - lineThickness / 2)
                    let p2Inside = simd_float2(x: center.x + deltaX, y: center.y + deltaY)
                    
                    deltaX = cos(angle2) * widthPerPixel / scopeState.texAspect * (radius + lineThickness / 2)
                    deltaY = sin(angle2) * widthPerPixel * (radius + lineThickness / 2)
                    let p2Outside = simd_float2(x: center.x + deltaX, y: center.y + deltaY)
                    
                    verticies += [p1Inside, p1Outside, p2Inside, p2Outside]
                }
                
                uniforms = Uniforms(
                    color: color,
                    drawWithTetxure: false,
                    drawTextureTriangles: false,
                    textureTriangle:  trianglePoints,
                    texAspect: texAspect,
                    orthoMatrix: orthoMatrix,
                    flipTextureY: false
                )
                
                encoder.setVertexBytes(verticies, length: MemoryLayout<simd_float2>.stride * verticies.count, index: 0)
                
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: verticies.count)
            }
        
        func drawSquare(
            center: simd_float2,
            color: SIMD4<Float>,
            width: Float,
            orthoMatrix: float4x4,
            texAspect: Float,
            asDiamond: Bool = false) {
                
                let width = width * scale
                let center: simd_float2 = simd_float2(x: center.x, y: center.y)
                let widthPerPixel: Float = 1 / Float(view.drawableSize.width)
                let yOffset = (widthPerPixel * width)
                let xOffset = (widthPerPixel * width / scopeState.texAspect)
                let p1: simd_float2
                let p2: simd_float2
                let p3: simd_float2
                let p4: simd_float2
                if !asDiamond {
                    p1 = simd_float2(x: center.x - xOffset, y: center.y + yOffset)
                    p2 = simd_float2(x: center.x + xOffset, y: center.y + yOffset)
                    p3 = simd_float2(x: center.x + xOffset, y: center.y - yOffset)
                    p4 = simd_float2(x: center.x - xOffset, y: center.y - yOffset)
                    
                } else {
                    p1 = simd_float2(x: center.x, y: center.y + yOffset)
                    p2 = simd_float2(x: center.x + xOffset, y: center.y)
                    p3 = simd_float2(x: center.x, y: center.y - yOffset)
                    p4 = simd_float2(x: center.x - xOffset, y: center.y)
                }
                
                var verts: [simd_float2] = [p1, p2, p3]
                
                let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
                
                var uniforms: Uniforms = Uniforms(
                    color: color,
                    drawWithTetxure: false,
                    drawTextureTriangles: false,
                    textureTriangle:  trianglePoints,
                    texAspect: texAspect,
                    orthoMatrix: orthoMatrix,
                    flipTextureY: false
                )
                
                encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                
                verts = [p1, p3, p4]
                
                encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                
            }
        
        func drawArrowHead(
            point: simd_float2,
            size: Float,
            direction: ArrowHeadDirection,
            color: SIMD4<Float>,
            thickness: Float,
            orthoMatrix: float4x4,
            texAspect: Float) {
                let thickness = thickness * scale
                let widthPerPixel: Float = 1 / Float(view.drawableSize.width)
                
                let tipXOffset = (direction == .left ? -widthPerPixel * thickness / 2 : 0) / scopeState.texAspect
                let tipYOffset = (direction == .down ? -widthPerPixel * thickness / 2 : 0)
                
                let point = simd_float2(point.x + (direction == .left ? tipXOffset / 2 : 0), point.y + (direction == .down ? tipYOffset / 2 : 0))
                
                let deltaX = Float(sqrt(2)) / 2 * size * scale * widthPerPixel / scopeState.texAspect
                let deltaY = Float(sqrt(2)) / 2 * size * scale * widthPerPixel
                let pointTip = simd_float2(
                    point.x + tipXOffset * (direction == .down ? 0 : 1),
                    point.y + tipYOffset * (direction == .left ? 0 : 1)
                )
                let trailingPoint = simd_float2(
                    point.x - tipXOffset,
                    point.y - tipYOffset
                )
                let leadingOutsidePoint = simd_float2(
                    pointTip.x + deltaX,
                    pointTip.y + deltaY
                )
                let trailingOutsidePoint = simd_float2(
                    leadingOutsidePoint.x - tipXOffset * 2,
                    leadingOutsidePoint.y - tipYOffset * 2
                )
                
                let leadingInsidePoint = simd_float2(
                    pointTip.x + deltaX * (direction == .down ? -1 : 1),
                    pointTip.y + deltaY * (direction == .down ? 1 : -1)
                )
                
                let trailingInsidePoint = simd_float2(
                    leadingInsidePoint.x + tipXOffset * 2 * (direction == .down ? 1 : -1),
                    leadingInsidePoint.y + tipYOffset * 2 * (direction == .down ? -1 : 1)
                )
                let verticies: [simd_float2] = [leadingOutsidePoint,
                                                trailingOutsidePoint,
                                                pointTip,
                                                trailingPoint,
                                                leadingInsidePoint,
                                                trailingInsidePoint,
                ]
                let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
                
                var uniforms: Uniforms = Uniforms(
                    color: color,
                    drawWithTetxure: false,
                    drawTextureTriangles: false,
                    textureTriangle:  trianglePoints,
                    texAspect: texAspect,
                    orthoMatrix: orthoMatrix,
                    flipTextureY: false
                )
                encoder.setVertexBytes(verticies, length: MemoryLayout<simd_float2>.stride * verticies.count, index: 0)
                
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: verticies.count)
                
            }
        
        func drawThickLine(
            p1: simd_float2,
            p2: simd_float2,
            color: SIMD4<Float>,
            thickness: Float,
            orthoMatrix: float4x4,
            texAspect: Float) {
                
                let thickness = thickness * scale
                let dir = normalize(p2 - p1)
                let normal = simd_float2(-dir.y, dir.x) * thickness / 2
                let v0 = p1 + normal
                let v1 = p1 - normal
                let v2 = p2 + normal
                let v3 = p2 - normal
                let vertices = [v0, v1, v2, v3]
                encoder.setVertexBytes(vertices, length: MemoryLayout<simd_float2>.stride * 4, index: 0)
                let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
                
                var uniforms: Uniforms = Uniforms(
                    color: color,
                    drawWithTetxure: false,
                    drawTextureTriangles: false,
                    textureTriangle:  trianglePoints,
                    texAspect: texAspect,
                    orthoMatrix: orthoMatrix,
                    flipTextureY: false
                )
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {


        drawableSize = size
        Task { @MainActor in
            let newScale: CGFloat
    #if os(macOS)
            if let backingScaleFactor = mtkView?.window?.screen?.backingScaleFactor
            {
                newScale = CGFloat(backingScaleFactor)
            } else {
                print("backingScaleFactor is nil!")
                newScale = 1
            }
    #else
            newScale = CGFloat(mtkView?.contentScaleFactor ?? 1)
    #endif
            let scaledSize =   CGSize(width: size.width/newScale, height: size.height/newScale)
            //print("In SourceImageRenderer, scale = \(newScale). scaled image size = \(scaledSize)")

            scopeState.imageViewSize = scaledSize
        }
    }
}

