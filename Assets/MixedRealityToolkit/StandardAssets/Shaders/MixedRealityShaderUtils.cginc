// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_SHADER_UTILS
#define MRTK_SHADER_UTILS

// SDF methods from: https://www.shadertoy.com/view/Xds3zN

#if defined(_CLIPPING_PLANE)
inline float PointVsPlane(float3 worldPosition, float4 plane)
{
    float3 planePosition = plane.xyz * plane.w;
    return dot(worldPosition - planePosition, plane.xyz);
}
#endif

#if defined(_CLIPPING_SPHERE)
inline float PointVsSphere(float3 worldPosition, float4 sphere)
{
    return distance(worldPosition, sphere.xyz) - sphere.w;
}
#endif

#if defined(_CLIPPING_BOX)
inline float PointVsBox(float3 worldPosition, float3 boxSize, float4x4 boxInverseTransform)
{
    float3 distance = abs(mul(boxInverseTransform, float4(worldPosition, 1.0))) - boxSize;
    return length(max(distance, 0.0)) + min(max(distance.x, max(distance.y, distance.z)), 0.0);
}
#endif

#if defined(_CLIPPING_CONE)
inline float PointVsCone(float3 worldPosition, float3 clipConeStart, float3 clipConeEnd, float2 clipConeRadii)
{
    float3 p = worldPosition;
    float3 a = clipConeStart;
    float3 b = clipConeEnd;
    float ra = clipConeRadii.x;
    float rb = clipConeRadii.y;

    float rba = rb - ra;
    float baba = dot(b - a, b - a);
    float papa = dot(p - a, p - a);
    float paba = dot(p - a, b - a) / baba;

    float x = sqrt(papa - paba * paba * baba);

    float cax = max(0.0, x - ((paba < 0.5) ? ra : rb));
    float cay = abs(paba - 0.5) - 0.5;

    float k = rba * rba + baba;
    float f = clamp((rba * (x - ra) + paba * baba) / k, 0.0, 1.0);

    float cbx = x - ra - f * rba;
    float cby = paba - f;

    float s = (cbx < 0.0 && cay < 0.0) ? -1.0 : 1.0;

    return s * sqrt(min(cax * cax + cay * cay * baba, cbx * cbx + cby * cby * baba));
}
#endif

#if defined(_CLIPPING_PYRAMID)
inline float PointVsPyramid(float3 worldPosition, float pyramidHeight, float4x4 pyramidInverseTransform)
{
    float3 p = mul(pyramidInverseTransform, float4(worldPosition, 1.0));
    float h = pyramidHeight;

    float m2 = h * h + 0.25;

    // Symmetry.
    p.xz = abs(p.xz);
    p.xz = (p.z > p.x) ? p.zx : p.xz;
    p.xz -= 0.5;

    // Project into face plane (2D).
    float3 q = float3(p.z, h * p.y - 0.5 * p.x, h * p.x + 0.5 * p.y);

    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * p.z) / (m2 + 0.25), 0.0, 1.0);

    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);

    float d2 = min(q.y, -q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);

    // Recover 3D and scale, and add sign.
    return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p.y));;
}
#endif

#endif