// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_UTILITIES_INCLUDE
#define MRTK_STANDARD_UTILITIES_INCLUDE

/// <summary>
/// Calculates the distance between the camera and a local position.
/// </summary>
inline float DistanceToCameraLocal(float4 localPosition)
{
    return -UnityObjectToViewPos(localPosition).z;
}

/// <summary>
/// Calculates the distance between the camera and a world position.
/// </summary>
inline float DistanceToCameraWorld(float3 worldPosition)
{
    return distance(worldPosition, _WorldSpaceCameraPos);
}

/// <summary>
/// Lights greater than or equal to this distance are not considered in distance calculations.
/// </summary>
static const float _LightCullDistance = 10.0;

/// <summary>
/// Calculates the distance between the specified light and a vertex. If the light is disabled the distance will be
/// greater than or equal to the "_LightCullDistance."
/// </summary>
inline float DistanceToLight(float4 light, float3 worldPosition)
{
    return distance(worldPosition, light.xyz) + ((1.0 - light.w) * _LightCullDistance);
}

/// <summary>
/// Calculates the distance between the nearest light and a vertex.
/// </summary>
inline float DistanceToNearestLight(float3 worldPosition)
{
    float output = _LightCullDistance;

    [unroll]
    for (int hoverLightIndex = 0; hoverLightIndex < HOVER_LIGHT_COUNT; ++hoverLightIndex)
    {
        int dataIndex = hoverLightIndex * HOVER_LIGHT_DATA_SIZE;
        output = min(output, DistanceToLight(_HoverLightData[dataIndex], worldPosition));
    }

    [unroll]
    for (int proximityLightIndex = 0; proximityLightIndex < PROXIMITY_LIGHT_COUNT; ++proximityLightIndex)
    {
        int dataIndex = proximityLightIndex * PROXIMITY_LIGHT_DATA_SIZE;
        output = min(output, DistanceToLight(_ProximityLightData[dataIndex], worldPosition));
    }

    return output;
}

/// <summary>
/// Calculates the tangent matrix basis vectors for use with normal mapping.
/// </summary>
inline void CalculateTangentBasis(fixed3 worldNormal,
                                  fixed4 tangent,
                                  out fixed3 tangentX,
                                  out fixed3 tangentY,
                                  out fixed3 tangentZ)
{
    fixed3 worldTangent = UnityObjectToWorldDir(tangent.xyz);
    fixed tangentSign = tangent.w * unity_WorldTransformParams.w;
    fixed3 worldBitangent = cross(worldNormal, worldTangent) * tangentSign;
    tangentX = fixed3(worldTangent.x, worldBitangent.x, worldNormal.x);
    tangentY = fixed3(worldTangent.y, worldBitangent.y, worldNormal.y);
    tangentZ = fixed3(worldTangent.z, worldBitangent.z, worldNormal.z);
}

/// <summary>
/// Extracts the world scale from the unity_ObjectToWorld matrix.
/// </summary>
inline float3 ExtractScale(VertexInput input)
{
    float3 output;

    output.x = length(mul(unity_ObjectToWorld, float4(1.0, 0.0, 0.0, 0.0)));
    output.y = length(mul(unity_ObjectToWorld, float4(0.0, 1.0, 0.0, 0.0)));

#if defined(_IGNORE_Z_SCALE)
    output.z = output.x;
#else
    output.z = length(mul(unity_ObjectToWorld, float4(0.0, 0.0, 1.0, 0.0)));
#endif

#if !defined(_VERTEX_EXTRUSION_SMOOTH_NORMALS)
    // uv3.y will contain a negative value when rendered by a UGUI and ScaleMeshEffect.
    if (input.uv3.y < 0.0)
    {
        output.x *= input.uv2.x;
        output.y *= input.uv2.y;
        output.z *= input.uv3.x;
    }
#endif

    return output;
}

/// <summary>
/// Extrudes a vertex along a normal by a distance.
/// </summary>
inline float3 ExtrudeVertex(float3 vertexPosition, float3 normal, float distance)
{
    return vertexPosition + (normal * distance);
}

/// <summary>
/// Calculates the UV coordinates along three planes based on a position and surface normal.
/// </summary>
inline void CalculateTriplanarUVs(fixed3 normal,
                                  float3 position,
                                  float sharpness, 
                                  float4 textureScaleTranslation, 
                                  out float3 triplanarBlend,
                                  out float3 triplanarAxisSign,
                                  out float2 uvX, 
                                  out float2 uvY, 
                                  out float2 uvZ)
{
    // Calculate triplanar uvs and apply texture scale and offset values like TRANSFORM_TEX.
    triplanarBlend = pow(abs(normal), sharpness);
    triplanarBlend /= dot(triplanarBlend, fixed3(1.0, 1.0, 1.0));
    uvX = mad(position.zy, textureScaleTranslation.xy, textureScaleTranslation.zw);
    uvY = mad(position.xz, textureScaleTranslation.xy, textureScaleTranslation.zw);
    uvZ = mad(position.xy, textureScaleTranslation.xy, textureScaleTranslation.zw);

    // Ternary operator is 2 instructions faster than sign() when we don't care about zero returning a zero sign.
    triplanarAxisSign = normal < 0 ? -1 : 1;
    uvX.x *= triplanarAxisSign.x;
    uvY.x *= triplanarAxisSign.y;
    uvZ.x *= -triplanarAxisSign.z;
}

/// <summary>
/// Transforms the tangent space normal into a world normal.
/// </summary>
inline fixed3 TangentNormalToWorldNormal(fixed3 tangentNormal, 
                                         fixed3 tangentX, 
                                         fixed3 tangentY, 
                                         fixed3 tangentZ, 
                                         fixed triangleFacing)
{
    return normalize(fixed3(dot(tangentX, tangentNormal),
                            dot(tangentY, tangentNormal), 
                            dot(tangentZ, tangentNormal)) * triangleFacing);
}

/// <summary>
/// Calculates the blended world space normal from a tangent space normal.
/// </summary>
inline fixed3 TangentNormalToWorldNormalTriplanar(fixed3 worldNormal,
                                                  fixed3 tangentNormalX,
                                                  fixed3 tangentNormalY, 
                                                  fixed3 tangentNormalZ,
                                                  float3 triplanarBlend,
                                                  float3 triplanarAxisSign,
                                                  fixed triangleFacing)
{
    tangentNormalX.x *= triplanarAxisSign.x;
    tangentNormalY.x *= triplanarAxisSign.y;
    tangentNormalZ.x *= -triplanarAxisSign.z;

    // Swizzle world normals to match tangent space and apply whiteout normal blend.
    tangentNormalX = fixed3(tangentNormalX.xy + worldNormal.zy, tangentNormalX.z * worldNormal.x);
    tangentNormalY = fixed3(tangentNormalY.xy + worldNormal.xz, tangentNormalY.z * worldNormal.y);
    tangentNormalZ = fixed3(tangentNormalZ.xy + worldNormal.xy, tangentNormalZ.z * worldNormal.z);

    // Swizzle tangent normals to match world normal and blend together.
    return normalize((tangentNormalX.zyx * triplanarBlend.x +
                      tangentNormalY.xzy * triplanarBlend.y +
                      tangentNormalZ.xyz * triplanarBlend.z) * triangleFacing);
}

#endif // MRTK_STANDARD_UTILITIES_INCLUDE
