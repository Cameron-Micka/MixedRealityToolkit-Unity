// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_SHADER_UTILS
#define MRTK_SHADER_UTILS

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

#endif