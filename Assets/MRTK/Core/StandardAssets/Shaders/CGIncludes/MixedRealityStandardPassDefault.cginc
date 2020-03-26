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

    float2 halfScale2D = input.scale.xy * 0.5;
    float2 cornerCircleDistance = halfScale2D - (_RoundCornerMargin * input.scale.z) - cornerCircleRadius;

    float2 cornerPosition = distanceToUVEdge * halfScale2D;
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

    // Calculate the fluent light contributions.
#if defined(_FLUENT_LIGHT)
    fixed fluentLightContribution;
    fixed3 fluentLightColor;
#if defined(_NORMAL)
    FluentLight(input.worldPosition.xyz, worldNormal, fluentLightContribution, fluentLightColor);
#else
    FluentLight(input.worldPosition.xyz, fixed3(0.0, 0.0, 0.0), fluentLightContribution, fluentLightColor);
#endif
#endif

    // Calculate and apply light contribution due to border lighting.
#if defined(_BORDER_LIGHT)
    fixed borderValue;
#if defined(_ROUND_CORNERS)
    borderValue = BorderValueRound(currentCornerRadius, 
                                   cornerCircleRadius, 
                                   cornerCircleDistance, 
                                   cornerPosition, 
                                   halfScale2D, 
                                   input.scale.z);
#else
    borderValue = BorderValue(input.uv, distanceToUVEdge);
#endif
#if defined(_FLUENT_LIGHT)
    BorderLight(borderValue, fluentLightContribution, fluentLightColor, albedo);
#else
    BorderLight(borderValue, 0.0, fixed3(0.0, 0.0, 0.0), albedo);
#endif
#endif
#if defined(_ROUND_CORNERS)
    albedo *= roundCornerClip;
#if defined(_FLUENT_LIGHT)
    fluentLightContribution *= roundCornerClip;
#endif
#endif

    // Clip the current pixel based on the albedo alpha value.
#if defined(_ALPHA_CLIP)
#if defined(_CLIPPING_PRIMITIVE)
    albedo *= (primitiveDistance > 0.0);
#endif
    AlbedoClip(_Cutoff, albedo);
#endif

    // Final lighting mix.
    fixed4 output;

#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
    float4 lightDirection = _MainLightPosition;
#else
    float4 lightDirection = _WorldSpaceLightPos0;
#endif

    IBLInput iblInput = (IBLInput)0;
#if defined(_REFLECTIONS)
    iblInput.incidentVector = incidentVector;
    iblInput.worldNormal = worldNormal;
    iblInput.smoothness = _Smoothness;
#endif
#if defined(_REFRACTION)
    iblInput.refractiveIndex = _RefractiveIndex;
#endif

    SurfaceInput surfaceInput = (SurfaceInput)0;
    surfaceInput.albedo = albedo;
#if defined(_SPHERICAL_HARMONICS)
    surfaceInput.ambient = input.ambient;
#else
    surfaceInput.ambient = glstate_lightmodel_ambient + fixed3(0.25, 0.25, 0.25);
#endif
    surfaceInput.metallic = _Metallic;
    surfaceInput.smoothness = _Smoothness;
#if defined(_FRESNEL) || defined(_RIM_LIGHT)
    FresnelInput fresnelInput = (FresnelInput)0;
    fresnelInput.worldNormal = worldNormal;
    fresnelInput.worldViewVector = worldViewVector;
#if defined(_RIM_LIGHT)
    fresnelInput.rimColor = _RimColor;
    fresnelInput.rimPower = _RimPower;
#else
    fresnelInput.smoothness = _Smoothness;
#endif
    surfaceInput.fresnel = CalculateFresnel(fresnelInput);
#endif
#if defined(_DIRECTIONAL_LIGHT) || defined(_REFLECTIONS)
    surfaceInput.ibl = CalculateIBL(iblInput);
#if defined(_DIRECTIONAL_LIGHT)
    surfaceInput.diffuse = CalculateDiffuse(worldNormal, lightDirection);
#if defined(_SPECULAR_HIGHLIGHTS)
    surfaceInput.specular = CalculateSpecular(worldNormal, worldViewVector, lightDirection, _Metallic, _Smoothness);
#endif
#endif
#endif
#if defined(_EMISSION)
    surfaceInput.emission = _EmissiveColor;
#endif

    output = CalculateLighting(surfaceInput);

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
#if defined(_FLUENT_LIGHT)
                output.rgb += fluentLightColor * _FluentLightIntensity * fluentLightContribution;
#endif

                // Perform non-alpha clipped primitive clipping on the final output.
#if defined(_CLIPPING_PRIMITIVE) && !defined(_ALPHA_CLIP)
                output *= saturate(primitiveDistance * (1.0f / _BlendedClippingWidth));
#endif
                return output;
}

#endif // MRTK_STANDARD_PASS_DEFAULT_INCLUDE
