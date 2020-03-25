// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_PASS_DEFAULT_INCLUDE
#define MRTK_STANDARD_PASS_DEFAULT_INCLUDE

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardUtils.cginc"

#include "CGIncludes/MixedRealityStandardConfig.cginc"
#include "CGIncludes/MixedRealityStandardInput.cginc"
#include "CGIncludes/MixedRealityStandardUtilities.cginc"
#include "CGIncludes/MixedRealityStandardLighting.cginc"
#include "CGIncludes/MixedRealityStandardFluent.cginc"
#include "CGIncludes/MixedRealityStandardClipping.cginc"


/// <summary>
/// Prepares vertex data passed in from the application, such as vertex position, normal, etc. for use in the fragment 
/// shader.
/// </summary>
FragmentInput VertexShaderFunction(VertexInput input)
{
    FragmentInput output;

    // Setup instance IDs for single pass instanced rendering.
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // Copy the instance ID from the input structure to the output structure.
#if defined(_INSTANCED_COLOR)
    UNITY_TRANSFER_INSTANCE_ID(input, output);
#endif

    float4 localVertexPosition = input.vertex;

    // Transform the local vertex position into world space.
#if defined(_WORLD_POSITION) || defined(_VERTEX_EXTRUSION)
    float3 worldVertexPosition = mul(unity_ObjectToWorld, localVertexPosition).xyz;
#endif

    // Extract the scale in world space.
#if defined(_SCALE)
    output.scale = ExtractScale(input);
#endif

    fixed3 localNormal = input.normal;

    // Transform the local space normal into world space.
#if defined(_NORMAL) || defined(_VERTEX_EXTRUSION)
    fixed3 worldNormal = UnityObjectToWorldNormal(localNormal);
#endif

    // If vertex extrusion is enabled, extrude the vertex in world space, then transform it back to local space.
#if defined(_VERTEX_EXTRUSION)
#if defined(_VERTEX_EXTRUSION_SMOOTH_NORMALS)
    fixed3 worldSmoothNormal = UnityObjectToWorldNormal(input.uv2 * output.scale);
    worldVertexPosition = ExtrudeVertex(worldVertexPosition, worldSmoothNormal, _VertexExtrusionValue);
#else
    worldVertexPosition = ExtrudeVertex(worldVertexPosition, worldNormal, _VertexExtrusionValue);
#endif
    localVertexPosition = mul(unity_WorldToObject, float4(worldVertexPosition, 1.0));
#endif

#if defined(_WORLD_POSITION)
    output.worldPosition.xyz = worldVertexPosition;
#endif

    // Transform the vertex position from local to clip space.
    output.position = UnityObjectToClipPos(localVertexPosition);

    // Store the near fade value into an unused output.
#if defined(_NEAR_PLANE_FADE)
    output.worldPosition.w = CalculateNearFade(worldVertexPosition, 
                                               _FadeBeginDistance, 
                                               _FadeCompleteDistance, 
                                               _FadeMinValue);
#endif

    // Transform the UV coordinates by the tiling and offset factors.
#if defined(_UV)
    output.uv.xy = TRANSFORM_TEX(input.uv, _MainTex);
#endif

    // If using any features which require scale, calculate the orthonormal scale.
#if defined(_BORDER_LIGHT) || defined(_ROUND_CORNERS)
    float4 orthonormalsScale = CalculateOrthonormalScale(output.scale, localNormal);
    output.scale.xyz = orthonormalsScale.xyz;
#if defined(_BORDER_LIGHT) 
    output.uv.zw = CalculateBorderLightScale(output.scale.xy, orthonormalsScale.w);
#endif
#endif

    // Transform the lightmap UVs.
#if defined(LIGHTMAP_ON)
    output.lightMapUV.xy = input.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#endif

    // Pass though the vertex color.
#if defined(_VERTEX_COLORS)
    output.color = input.color;
#endif

    // Sample from Unity light probes.
#if defined(_SPHERICAL_HARMONICS)
    output.ambient = ShadeSH9(float4(worldNormal, 1.0));
#endif

    // Calculate the iridescent color. i.e. a color which changes based on view angle.
#if defined(_IRIDESCENCE)
    output.iridescentColor = Iridescence(input.uv, 
                                         _IridescentSpectrumMap,
                                         _IridescenceThreshold, 
                                         _IridescenceAngle, 
                                         _IridescenceIntensity);
#endif

    // Pass though the various normal types and tangents.
#if defined(_NORMAL)
#if defined(_TRIPLANAR_MAPPING)
    output.worldNormal = worldNormal;
#if defined(_LOCAL_SPACE_TRIPLANAR_MAPPING)
    output.triplanarNormal = localNormal;
    output.triplanarPosition = localVertexPosition;
#else
    output.triplanarNormal = worldNormal;
    output.triplanarPosition = output.worldPosition;
#endif
#elif defined(_NORMAL_MAP)
    CalculateTangentBasis(worldNormal, input.tangent, output.tangentX, output.tangentY, output.tangentZ);
#else
    output.worldNormal = worldNormal;
#endif
#endif

    return output;
}


fixed4 FragmentShaderFunction(FragmentInput input, fixed triangleFacing : VFACE) : SV_Target
{
    // Initialize the input for any uses of UNITY_ACCESS_INSTANCED_PROP.
#if defined(_INSTANCED_COLOR)
    UNITY_SETUP_INSTANCE_ID(input);
#endif

    // Calculate triplanar mapping UVs and blending parameters.
#if defined(_TRIPLANAR_MAPPING)
    float2 uvX, uvY, uvZ;
    float3 triplanarBlend, triplanarAxisSign;
    CalculateTriplanarUVs(input.triplanarNormal, 
                          input.triplanarPosition, 
                          _TriplanarMappingBlendSharpness, 
                          _MainTex_ST, 
                          triplanarBlend, 
                          triplanarAxisSign, 
                          uvX, uvY, uvZ);
#endif

    // Determine the initial albedo color.
#if defined(_DISABLE_ALBEDO_MAP)
    fixed4 albedo = fixed4(1.0, 1.0, 1.0, 1.0);
#else
#if defined(_TRIPLANAR_MAPPING)
    fixed4 albedo = tex2D(_MainTex, uvX) * triplanarBlend.x +
                    tex2D(_MainTex, uvY) * triplanarBlend.y +
                    tex2D(_MainTex, uvZ) * triplanarBlend.z;
#else
    fixed4 albedo = tex2D(_MainTex, input.uv);
#endif
#endif

    // Darken the albedo based on the lightmap.
#ifdef LIGHTMAP_ON
    albedo.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, input.lightMapUV));
#endif

    // Unpack material properties from the channel texture, or main texture.
#if defined(_CHANNEL_MAP)
#if defined(_EMISSION)
    DecodeChannelMap(tex2D(_ChannelMap, input.uv), albedo.rgb, _EmissiveColor, _Metallic, _Smoothness);
#else
    fixed3 emission = fixed3(0.0, 0.0, 0.0);
    DecodeChannelMap(tex2D(_ChannelMap, input.uv), albedo.rgb, emission, _Metallic, _Smoothness);
#endif
#elif defined(_METALLIC_TEXTURE_ALBEDO_CHANNEL_A)
    _Metallic = albedo.a;
    albedo.a = 1.0;
#elif defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    _Smoothness = albedo.a;
    albedo.a = 1.0;
#endif

    // Apply color properties.
#if defined(_INSTANCED_COLOR)
    albedo *= UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
#else
    albedo *= _Color;
#endif
#if defined(_VERTEX_COLORS)
    albedo *= input.color;
#endif
#if defined(_IRIDESCENCE)
    albedo.rgb += input.iridescentColor;
#endif

    // Primitive clipping.
#if defined(_CLIPPING_PRIMITIVE)
    float primitiveDistance = CalculateMinClippingPrimitiveDistance(input.worldPosition.xyz);
#if defined(_CLIPPING_BORDER)
    albedo.rgb += CalculateClippingPrimitiveBorderColor(primitiveDistance);
#endif
#endif

    // Common Fluent feature properties.
#if defined(_DISTANCE_TO_EDGE)
    float2 distanceToUVEdge = CalculateDistanceToUVEdge(input.uv);
#endif

    // Rounded corner clipping.
#if defined(_ROUND_CORNERS)
    float currentCornerRadius = GetRoundCornerRadius(input.uv);
    float cornerCircleRadius = saturate(max(currentCornerRadius - _RoundCornerMargin, 0.01)) * input.scale.z;

    float2 halfScale = input.scale.xy * 0.5;
    float2 cornerCircleDistance = halfScale - (_RoundCornerMargin * input.scale.z) - cornerCircleRadius;

    float2 cornerPosition = distanceToUVEdge * halfScale;
    float roundCornerClip = RoundCorners(cornerPosition, cornerCircleDistance, cornerCircleRadius, _EdgeSmoothingValue);
#endif

#if defined(_NORMAL)
    // World normal calculation.
    fixed3 worldNormal;

#if defined(_NORMAL_MAP)
#if defined(_TRIPLANAR_MAPPING)
    fixed3 tangentNormalX = UnpackScaleNormal(tex2D(_NormalMap, uvX), _NormalMapScale);
    fixed3 tangentNormalY = UnpackScaleNormal(tex2D(_NormalMap, uvY), _NormalMapScale);
    fixed3 tangentNormalZ = UnpackScaleNormal(tex2D(_NormalMap, uvZ), _NormalMapScale);
    worldNormal = TangentNormalToWorldNormalTriplanar(input.worldNormal,
                                                      tangentNormalX, 
                                                      tangentNormalY, 
                                                      tangentNormalZ, 
                                                      triplanarBlend, 
                                                      triplanarAxisSign, 
                                                      triangleFacing);
#else
    fixed3 tangentNormal = UnpackScaleNormal(tex2D(_NormalMap, input.uv), _NormalMapScale);
    worldNormal = TangentNormalToWorldNormal(tangentNormal,
                                             input.tangentX, 
                                             input.tangentY, 
                                             input.tangentZ, 
                                             triangleFacing);
#endif
#else
    worldNormal = normalize(input.worldNormal) * triangleFacing;
#endif

    // World view vector calculation.
    fixed3 worldViewVector = normalize(UnityWorldSpaceViewDir(input.worldPosition.xyz));
#if defined(_REFLECTIONS) || defined(_ENVIRONMENT_COLORING)
    fixed3 incidentVector = -worldViewVector;
#endif
#endif

                // TODO
                fixed pointToLight = 1.0;
                fixed3 fluentLightColor = fixed3(0.0, 0.0, 0.0);

                // Hover light.
#if defined(_HOVER_LIGHT)
                pointToLight = 0.0;

                [unroll]
                for (int hoverLightIndex = 0; hoverLightIndex < HOVER_LIGHT_COUNT; ++hoverLightIndex)
                {
                    int dataIndex = hoverLightIndex * HOVER_LIGHT_DATA_SIZE;
                    fixed hoverValue = HoverLight(_HoverLightData[dataIndex], _HoverLightData[dataIndex + 1].w, input.worldPosition.xyz);
                    pointToLight += hoverValue;
#if !defined(_HOVER_COLOR_OVERRIDE)
                    fluentLightColor += lerp(fixed3(0.0, 0.0, 0.0), _HoverLightData[dataIndex + 1].rgb, hoverValue);
#endif
                }
#if defined(_HOVER_COLOR_OVERRIDE)
                fluentLightColor = _HoverColorOverride.rgb * pointToLight;
#endif
#endif

                // Proximity light.
#if defined(_PROXIMITY_LIGHT)
#if !defined(_HOVER_LIGHT)
                pointToLight = 0.0;
#endif
                [unroll]
                for (int proximityLightIndex = 0; proximityLightIndex < PROXIMITY_LIGHT_COUNT; ++proximityLightIndex)
                {
                    int dataIndex = proximityLightIndex * PROXIMITY_LIGHT_DATA_SIZE;
                    fixed colorValue;
                    fixed proximityValue = ProximityLight(_ProximityLightData[dataIndex], _ProximityLightData[dataIndex + 1], _ProximityLightData[dataIndex + 2], input.worldPosition.xyz, worldNormal, colorValue);
                    pointToLight += proximityValue;
#if defined(_PROXIMITY_LIGHT_COLOR_OVERRIDE)
                    fixed3 proximityColor = MixProximityLightColor(_ProximityLightCenterColorOverride, _ProximityLightMiddleColorOverride, _ProximityLightOuterColorOverride, colorValue);
#else
                    fixed3 proximityColor = MixProximityLightColor(_ProximityLightData[dataIndex + 3], _ProximityLightData[dataIndex + 4], _ProximityLightData[dataIndex + 5], colorValue);
#endif  
#if defined(_PROXIMITY_LIGHT_SUBTRACTIVE)
                    fluentLightColor -= lerp(fixed3(0.0, 0.0, 0.0), proximityColor, proximityValue);
#else
                    fluentLightColor += lerp(fixed3(0.0, 0.0, 0.0), proximityColor, proximityValue);
#endif    
                }
#endif    

                // Border light.
#if defined(_BORDER_LIGHT)
                fixed borderValue;
#if defined(_ROUND_CORNERS)
                fixed borderMargin = _RoundCornerMargin + _BorderWidth * 0.5;

                cornerCircleRadius = saturate(max(currentCornerRadius - borderMargin, 0.01)) * input.scale.z;

                cornerCircleDistance = halfScale - (borderMargin * input.scale.z) - cornerCircleRadius;

                borderValue = 1.0 - RoundCornersSmooth(cornerPosition, cornerCircleDistance, cornerCircleRadius, _EdgeSmoothingValue);
#else
                borderValue = max(smoothstep(input.uv.z - _EdgeSmoothingValue, input.uv.z + _EdgeSmoothingValue, distanceToUVEdge.x),
                                  smoothstep(input.uv.w - _EdgeSmoothingValue, input.uv.w + _EdgeSmoothingValue, distanceToUVEdge.y));
#endif
#if defined(_HOVER_LIGHT) && defined(_BORDER_LIGHT_USES_HOVER_COLOR) && defined(_HOVER_COLOR_OVERRIDE)
                fixed3 borderColor = _HoverColorOverride.rgb;
#else
                fixed3 borderColor = fixed3(1.0, 1.0, 1.0);
#endif
                fixed3 borderContribution = borderColor * borderValue * _BorderMinValue * _FluentLightIntensity;
#if defined(_BORDER_LIGHT_REPLACES_ALBEDO)
                albedo.rgb = lerp(albedo.rgb, borderContribution, borderValue);
#else
                albedo.rgb += borderContribution;
#endif
#if defined(_HOVER_LIGHT) || defined(_PROXIMITY_LIGHT)
                albedo.rgb += (fluentLightColor * borderValue * pointToLight * _FluentLightIntensity) * 2.0;
#endif
#if defined(_BORDER_LIGHT_OPAQUE)
                albedo.a = max(albedo.a, borderValue * _BorderLightOpaqueAlpha);
#endif
#endif

#if defined(_ROUND_CORNERS)
                albedo *= roundCornerClip;
                pointToLight *= roundCornerClip;
#endif

#if defined(_ALPHA_CLIP)
#if !defined(_ALPHATEST_ON)
                _Cutoff = 0.5;
#endif
#if defined(_CLIPPING_PRIMITIVE)
                albedo *= (primitiveDistance > 0.0);
#endif
                clip(albedo.a - _Cutoff);
                albedo.a = 1.0;
#endif

                // Blinn phong lighting.
#if defined(_DIRECTIONAL_LIGHT)
#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
                float4 directionalLightDirection = _MainLightPosition;
#else
                float4 directionalLightDirection = _WorldSpaceLightPos0;
#endif
                fixed diffuse = max(0.0, dot(worldNormal, directionalLightDirection));
#if defined(_SPECULAR_HIGHLIGHTS)
                fixed halfVector = max(0.0, dot(worldNormal, normalize(directionalLightDirection + worldViewVector)));
                fixed specular = saturate(pow(halfVector, _Shininess * pow(_Smoothness, 4.0)) * (_Smoothness * 2.0) * _Metallic);
#else
                fixed specular = 0.0;
#endif
#endif

                // Image based lighting (attempt to mimic the Standard shader).
#if defined(_REFLECTIONS)
                fixed3 worldReflection = reflect(incidentVector, worldNormal);
                fixed4 iblData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, worldReflection, (1.0 - _Smoothness) * UNITY_SPECCUBE_LOD_STEPS);
                fixed3 ibl = DecodeHDR(iblData, unity_SpecCube0_HDR);
#if defined(_REFRACTION)
                fixed4 refractColor = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refract(incidentVector, worldNormal, _RefractiveIndex));
                ibl *= DecodeHDR(refractColor, unity_SpecCube0_HDR);
#endif
#else
                fixed3 ibl = unity_IndirectSpecColor.rgb;
#endif

                // Fresnel lighting.
#if defined(_FRESNEL)
                fixed fresnel = 1.0 - saturate(abs(dot(worldViewVector, worldNormal)));
#if defined(_RIM_LIGHT)
                fixed3 fresnelColor = _RimColor * pow(fresnel, _RimPower);
#else
                fixed3 fresnelColor = unity_IndirectSpecColor.rgb * (pow(fresnel, _FresnelPower) * max(_Smoothness, 0.5));
#endif
#endif
                // Final lighting mix.
                fixed4 output = albedo;
#if defined(_SPHERICAL_HARMONICS)
                fixed3 ambient = input.ambient;
#else
                fixed3 ambient = glstate_lightmodel_ambient + fixed3(0.25, 0.25, 0.25);
#endif
                fixed minProperty = min(_Smoothness, _Metallic);
#if defined(_DIRECTIONAL_LIGHT)
                fixed oneMinusMetallic = (1.0 - _Metallic);
                output.rgb = lerp(output.rgb, ibl, minProperty);
#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
                fixed3 directionalLightColor = _MainLightColor.rgb;
#else
                fixed3 directionalLightColor = _LightColor0.rgb;
#endif
                output.rgb *= lerp((ambient + directionalLightColor * diffuse + directionalLightColor * specular) * max(oneMinusMetallic, _MinMetallicLightContribution), albedo, minProperty);
                output.rgb += (directionalLightColor * albedo * specular) + (directionalLightColor * specular * _Smoothness);
                output.rgb += ibl * oneMinusMetallic * _IblContribution;
#elif defined(_REFLECTIONS)
                output.rgb = lerp(output.rgb, ibl, minProperty);
                output.rgb *= lerp(ambient, albedo, minProperty);
#elif defined(_SPHERICAL_HARMONICS)
                output.rgb *= ambient;
#endif

#if defined(_FRESNEL)
#if defined(_RIM_LIGHT) || !defined(_REFLECTIONS)
                output.rgb += fresnelColor;
#else
                output.rgb += fresnelColor * (1.0 - minProperty);
#endif
#endif

#if defined(_EMISSION)
    output.rgb += _EmissiveColor;
#endif

                // Inner glow.
#if defined(_INNER_GLOW)
                fixed2 uvGlow = pow(distanceToUVEdge * _InnerGlowColor.a, _InnerGlowPower);
                output.rgb += lerp(fixed3(0.0, 0.0, 0.0), _InnerGlowColor.rgb, uvGlow.x + uvGlow.y);
#endif

                // Environment coloring.
#if defined(_ENVIRONMENT_COLORING)
                fixed3 environmentColor = incidentVector.x * incidentVector.x * _EnvironmentColorX +
                                          incidentVector.y * incidentVector.y * _EnvironmentColorY +
                                          incidentVector.z * incidentVector.z * _EnvironmentColorZ;
                output.rgb += environmentColor * max(0.0, dot(incidentVector, worldNormal) + _EnvironmentColorThreshold) * _EnvironmentColorIntensity;

#endif

#if defined(_NEAR_PLANE_FADE)
                output *= input.worldPosition.w;
#endif

                // Hover and proximity lighting should occur after near plane fading.
#if defined(_HOVER_LIGHT) || defined(_PROXIMITY_LIGHT)
                output.rgb += fluentLightColor * _FluentLightIntensity * pointToLight;
#endif

                // Perform non-alpha clipped primitive clipping on the final output.
#if defined(_CLIPPING_PRIMITIVE) && !defined(_ALPHA_CLIP)
                output *= saturate(primitiveDistance * (1.0f / _BlendedClippingWidth));
#endif
                return output;
}

#endif // MRTK_STANDARD_PASS_DEFAULT_INCLUDE
