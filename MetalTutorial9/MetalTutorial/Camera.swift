import Foundation
import simd

class Camera {
    var position = simd_float3(0.0, 1.0, -4.0)
    var direction = simd_float3(0.0, 0.0, 1.0)
    
    var up = simd_float3(0.0, 1.0, 0.0)
    
    func getViewMatrix() -> simd_float4x4 {
        return createViewMatrix(eyePosition: position, targetPosition: position + direction, upVec: up)
    }
    
    func rotate(rotationAngles: simd_float2) {
        direction = rotateVectorAroundNormal(vec: direction, angle: rotationAngles.y, normal: normalize(cross(direction, up)))
        direction = rotateVectorAroundNormal(vec: direction, angle: rotationAngles.x, normal: up)
    }
}
