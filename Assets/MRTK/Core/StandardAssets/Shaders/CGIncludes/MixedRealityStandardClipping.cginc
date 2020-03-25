// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_CLIPPING_INCLUDE
#define MRTK_STANDARD_CLIPPING_INCLUDE

/// <summary>
/// Clipping properties.
/// </summary>
#if defined(_CLIPPING_PLANE)
fixed _ClipPlaneSide;
float4 _ClipPlane;
#endif

#if defined(_CLIPPING_SPHERE)
fixed _ClipSphereSide;
float4 _ClipSphere;
#endif

#if defined(_CLIPPING_BOX)
fixed _ClipBoxSide;
float4 _ClipBoxSize;
float4x4 _ClipBoxInverseTransform;
#endif

#if defined(_CLIPPING_PRIMITIVE)
float _BlendedClippingWidth;
#endif

#if defined(_CLIPPING_BORDER)
fixed _ClippingBorderWidth;
fixed3 _ClippingBorderColor;
#endif

/// <summary>
/// Returns the distance between a point and a plane. Distance is positive when the point is in the positive half-space,
/// negative when in the negative half-space, and zero when on the plane.
/// </summary>
inline float PointVsPlane(float3 worldPosition, float4 plane)
{
    float3 planePosition = plane.xyz * plane.w;
    return dot(worldPosition - planePosition, plane.xyz);
}

/// <summary>
/// Returns the distance between a point and a sphere. Distance is positive when the point is outside the sphere,
/// negative when in the sphere, and zero on the sphere.
/// </summary>
inline float PointVsSphere(float3 worldPosition, float4 sphere)
{
    return distance(worldPosition, sphere.xyz) - sphere.w;
}

/// <summary>
/// Returns the distance between a point and a box. Distance is positive when the point is outside the box,
/// negative when in the box, and zero on the box.
/// </summary>
inline float PointVsBox(float3 worldPosition, float3 boxSize, float4x4 boxInverseTransform)
{
    float3 distance = abs(mul(boxInverseTransform, float4(worldPosition, 1.0))) - boxSize;
    return length(max(distance, 0.0)) + min(max(distance.x, max(distance.y, distance.z)), 0.0);
}

/// <summary>
/// Returns the minimum distance from the currently enabled clipping primitives.
/// </summary>
inline float CalculateMinClippingPrimitiveDistance(float3 worldPosition)
{
    float output = 1.0;

#if defined(_CLIPPING_PLANE)
    output = min(output, PointVsPlane(worldPosition, _ClipPlane) * _ClipPlaneSide);
#endif
#if defined(_CLIPPING_SPHERE)
    output = min(output, PointVsSphere(worldPosition, _ClipSphere) * _ClipSphereSide);
#endif
#if defined(_CLIPPING_BOX)
    output = min(output, PointVsBox(worldPosition, _ClipBoxSize.xyz, _ClipBoxInverseTransform) * _ClipBoxSide);
#endif

    return output;
}

/// <summary>
/// Returns the interpolated border color to apply based on primitive distance.
/// </summary>
inline fixed3 CalculateClippingPrimitiveBorderColor(float primitiveDistance)
{
#if defined(_CLIPPING_BORDER)
    fixed3 output = lerp(_ClippingBorderColor, fixed3(0.0, 0.0, 0.0), primitiveDistance / _ClippingBorderWidth);
    return output * (primitiveDistance < _ClippingBorderWidth);
#else
    return fixed3(0.0, 0.0, 0.0);
#endif
}

#endif // MRTK_STANDARD_CLIPPING_INCLUDE
