import Foundation
import simd

func toRadians(from angle: Float) -> Float {
    return angle * .pi / 180.0;
}

func translateMatrix(matrix: inout simd_float4x4, position: simd_float3) {
    matrix[3] = matrix[0] * position.x + matrix[1] * position.y + matrix[2] * position.z + matrix[3];
}

func rotateMatrix(matrix: inout simd_float4x4, rotation: simd_float3) {
    //Create quaternion
    let c = cos(rotation * 0.5);
    let s = sin(rotation * 0.5);

    var quat = simd_float4(repeating: 1.0);

    quat.w = c.x * c.y * c.z + s.x * s.y * s.z;
    quat.x = s.x * c.y * c.z - c.x * s.y * s.z;
    quat.y = c.x * s.y * c.z + s.x * c.y * s.z;
    quat.z = c.x * c.y * s.z - s.x * s.y * c.z;

    //Create matrix
    var rotationMat = matrix_identity_float4x4;
    let qxx = quat.x * quat.x;
    let qyy = quat.y * quat.y;
    let qzz = quat.z * quat.z;
    let qxz = quat.x * quat.z;
    let qxy = quat.x * quat.y;
    let qyz = quat.y * quat.z;
    let qwx = quat.w * quat.x;
    let qwy = quat.w * quat.y;
    let qwz = quat.w * quat.z;

    rotationMat[0][0] = 1.0 - 2.0 * (qyy + qzz);
    rotationMat[0][1] = 2.0 * (qxy + qwz);
    rotationMat[0][2] = 2.0 * (qxz - qwy);

    rotationMat[1][0] = 2.0 * (qxy - qwz);
    rotationMat[1][1] = 1.0 - 2.0 * (qxx + qzz);
    rotationMat[1][2] = 2.0 * (qyz + qwx);

    rotationMat[2][0] = 2.0 * (qxz + qwy);
    rotationMat[2][1] = 2.0 * (qyz - qwx);
    rotationMat[2][2] = 1.0 - 2.0 * (qxx + qyy);

    matrix *= rotationMat;
}

func scaleMatrix(matrix: inout simd_float4x4, scale: simd_float3) {
    matrix[0] *= scale.x;
    matrix[1] *= scale.y;
    matrix[2] *= scale.z
}

func createViewMatrix(eyePosition: simd_float3, targetPosition: simd_float3, upVec: simd_float3) -> simd_float4x4 {
    let forward = normalize(targetPosition - eyePosition)
    let rightVec = normalize(simd_cross(upVec, forward))
    let up = simd_cross(forward, rightVec)
    
    var matrix = matrix_identity_float4x4;
    matrix[0][0] = rightVec.x;
    matrix[1][0] = rightVec.y;
    matrix[2][0] = rightVec.z;
    matrix[0][1] = up.x;
    matrix[1][1] = up.y;
    matrix[2][1] = up.z;
    matrix[0][2] = forward.x;
    matrix[1][2] = forward.y;
    matrix[2][2] = forward.z;
    matrix[3][0] = -dot(rightVec, eyePosition);
    matrix[3][1] = -dot(up, eyePosition);
    matrix[3][2] = -dot(forward, eyePosition);
    
    return matrix;
}

func createPerspectiveMatrix(fov: Float, aspectRatio: Float, nearPlane: Float, farPlane: Float) -> simd_float4x4 {
    let tanHalfFov = tan(fov / 2.0);

    var matrix = simd_float4x4(0.0);
    matrix[0][0] = 1.0 / (aspectRatio * tanHalfFov);
    matrix[1][1] = 1.0 / (tanHalfFov);
    matrix[2][2] = farPlane / (farPlane - nearPlane);
    matrix[2][3] = 1.0;
    matrix[3][2] = -(farPlane * nearPlane) / (farPlane - nearPlane);
    
    return matrix;
}
