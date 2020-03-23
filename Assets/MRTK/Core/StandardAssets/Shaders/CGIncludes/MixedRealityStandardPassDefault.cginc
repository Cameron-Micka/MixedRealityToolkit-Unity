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
    CalculateTangentMatrix(worldNormal, input.tangent, output.tangentX, output.tangentY, output.tangentZ);
#else
    output.worldNormal = worldNormal;
#endif
#endif

    return output;
}


fixed4 FragmentShaderFunction(FragmentInput i, fixed facing : VFACE) : SV_Target
{
#if defined(_INSTANCED_COLOR)
                UNITY_SETUP_INSTANCE_ID(i);
#endif

#if defined(_TRIPLANAR_MAPPING)
// Calculate triplanar uvs and apply texture scale and offset values like TRANSFORM_TEX.
fixed3 triplanarBlend = pow(abs(i.triplanarNormal), _TriplanarMappingBlendSharpness);
triplanarBlend /= dot(triplanarBlend, fixed3(1.0, 1.0, 1.0));
float2 uvX = i.triplanarPosition.zy * _MainTex_ST.xy + _MainTex_ST.zw;
float2 uvY = i.triplanarPosition.xz * _MainTex_ST.xy + _MainTex_ST.zw;
float2 uvZ = i.triplanarPosition.xy * _MainTex_ST.xy + _MainTex_ST.zw;

// Ternary operator is 2 instructions faster than sign() when we don't care about zero returning a zero sign.
float3 axisSign = i.triplanarNormal < 0 ? -1 : 1;
uvX.x *= axisSign.x;
uvY.x *= axisSign.y;
uvZ.x *= -axisSign.z;
#endif

// Texturing.
#if defined(_DISABLE_ALBEDO_MAP)
                fixed4 albedo = fixed4(1.0, 1.0, 1.0, 1.0);
#else
#if defined(_TRIPLANAR_MAPPING)
                fixed4 albedo = tex2D(_MainTex, uvX) * triplanarBlend.x +
                                tex2D(_MainTex, uvY) * triplanarBlend.y +
                                tex2D(_MainTex, uvZ) * triplanarBlend.z;
#else
                fixed4 albedo = tex2D(_MainTex, i.uv);
#endif
#endif

#ifdef LIGHTMAP_ON
                albedo.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightMapUV));
#endif

#if defined(_CHANNEL_MAP)
                fixed4 channel = tex2D(_ChannelMap, i.uv);
                _Metallic = channel.r;
                albedo.rgb *= channel.g;
                _Smoothness = channel.a;
#else
#if defined(_METALLIC_TEXTURE_ALBEDO_CHANNEL_A)
                _Metallic = albedo.a;
                albedo.a = 1.0;
#elif defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                _Smoothness = albedo.a;
                albedo.a = 1.0;
#endif 
#endif

                // Primitive clipping.
#if defined(_CLIPPING_PRIMITIVE)
                float primitiveDistance = 1.0;
#if defined(_CLIPPING_PLANE)
                primitiveDistance = min(primitiveDistance, PointVsPlane(i.worldPosition.xyz, _ClipPlane) * _ClipPlaneSide);
#endif
#if defined(_CLIPPING_SPHERE)
                primitiveDistance = min(primitiveDistance, PointVsSphere(i.worldPosition.xyz, _ClipSphere) * _ClipSphereSide);
#endif
#if defined(_CLIPPING_BOX)
                primitiveDistance = min(primitiveDistance, PointVsBox(i.worldPosition.xyz, _ClipBoxSize.xyz, _ClipBoxInverseTransform) * _ClipBoxSide);
#endif
#if defined(_CLIPPING_BORDER)
                fixed3 primitiveBorderColor = lerp(_ClippingBorderColor, fixed3(0.0, 0.0, 0.0), primitiveDistance / _ClippingBorderWidth);
                albedo.rgb += primitiveBorderColor * IF((primitiveDistance < _ClippingBorderWidth), 1.0, 0.0);
#endif
#endif

#if defined(_DISTANCE_TO_EDGE)
                fixed2 distanceToEdge;
                distanceToEdge.x = abs(i.uv.x - 0.5) * 2.0;
                distanceToEdge.y = abs(i.uv.y - 0.5) * 2.0;
#endif

                // Rounded corner clipping.
#if defined(_ROUND_CORNERS)
                float2 halfScale = i.scale.xy * 0.5;
                float2 roundCornerPosition = distanceToEdge * halfScale;

                fixed currentCornerRadius;

#if defined(_INDEPENDENT_CORNERS)

                _RoundCornersRadius = clamp(_RoundCornersRadius, 0, 0.5);

                if (i.uv.x < 0.5)
                {
                    if (i.uv.y > 0.5)
                    {
                        currentCornerRadius = _RoundCornersRadius.x;
                    }
                    else
                    {
                        currentCornerRadius = _RoundCornersRadius.w;
                    }
                }
                else
                {
                    if (i.uv.y > 0.5)
                    {
                        currentCornerRadius = _RoundCornersRadius.y;
                    }
                    else
                    {
                        currentCornerRadius = _RoundCornersRadius.z;
                    }
                }
#else 
                currentCornerRadius = _RoundCornerRadius;
#endif

                float cornerCircleRadius = saturate(max(currentCornerRadius - _RoundCornerMargin, 0.01)) * i.scale.z;

                float2 cornerCircleDistance = halfScale - (_RoundCornerMargin * i.scale.z) - cornerCircleRadius;

                float roundCornerClip = RoundCorners(roundCornerPosition, cornerCircleDistance, cornerCircleRadius, _EdgeSmoothingValue);
#endif

#if defined(_INSTANCED_COLOR)
                albedo *= UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
#else
                albedo *= _Color;
#endif

#if defined(_VERTEX_COLORS)
                albedo *= i.color;
#endif

#if defined(_IRIDESCENCE)
                albedo.rgb += i.iridescentColor;
#endif

                // Normal calculation.
#if defined(_NORMAL)
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPosition.xyz));
#if defined(_REFLECTIONS) || defined(_ENVIRONMENT_COLORING)
                fixed3 incident = -worldViewDir;
#endif
                fixed3 worldNormal;

#if defined(_NORMAL_MAP)
#if defined(_TRIPLANAR_MAPPING)
                fixed3 tangentNormalX = UnpackScaleNormal(tex2D(_NormalMap, uvX), _NormalMapScale);
                fixed3 tangentNormalY = UnpackScaleNormal(tex2D(_NormalMap, uvY), _NormalMapScale);
                fixed3 tangentNormalZ = UnpackScaleNormal(tex2D(_NormalMap, uvZ), _NormalMapScale);
                tangentNormalX.x *= axisSign.x;
                tangentNormalY.x *= axisSign.y;
                tangentNormalZ.x *= -axisSign.z;

                // Swizzle world normals to match tangent space and apply Whiteout normal blend.
                tangentNormalX = fixed3(tangentNormalX.xy + i.worldNormal.zy, tangentNormalX.z * i.worldNormal.x);
                tangentNormalY = fixed3(tangentNormalY.xy + i.worldNormal.xz, tangentNormalY.z * i.worldNormal.y);
                tangentNormalZ = fixed3(tangentNormalZ.xy + i.worldNormal.xy, tangentNormalZ.z * i.worldNormal.z);

                // Swizzle tangent normals to match world normal and blend together.
                worldNormal = normalize(tangentNormalX.zyx * triplanarBlend.x +
                                        tangentNormalY.xzy * triplanarBlend.y +
                                        tangentNormalZ.xyz * triplanarBlend.z);
#else
                fixed3 tangentNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv), _NormalMapScale);
                worldNormal.x = dot(i.tangentX, tangentNormal);
                worldNormal.y = dot(i.tangentY, tangentNormal);
                worldNormal.z = dot(i.tangentZ, tangentNormal);
                worldNormal = normalize(worldNormal) * facing;
#endif
#else
                worldNormal = normalize(i.worldNormal) * facing;
#endif
#endif

                fixed pointToLight = 1.0;
                fixed3 fluentLightColor = fixed3(0.0, 0.0, 0.0);

                // Hover light.
#if defined(_HOVER_LIGHT)
                pointToLight = 0.0;

                [unroll]
                for (int hoverLightIndex = 0; hoverLightIndex < HOVER_LIGHT_COUNT; ++hoverLightIndex)
                {
                    int dataIndex = hoverLightIndex * HOVER_LIGHT_DATA_SIZE;
                    fixed hoverValue = HoverLight(_HoverLightData[dataIndex], _HoverLightData[dataIndex + 1].w, i.worldPosition.xyz);
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
                    fixed proximityValue = ProximityLight(_ProximityLightData[dataIndex], _ProximityLightData[dataIndex + 1], _ProximityLightData[dataIndex + 2], i.worldPosition.xyz, worldNormal, colorValue);
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

                cornerCircleRadius = saturate(max(currentCornerRadius - borderMargin, 0.01)) * i.scale.z;

                cornerCircleDistance = halfScale - (borderMargin * i.scale.z) - cornerCircleRadius;

                borderValue = 1.0 - RoundCornersSmooth(roundCornerPosition, cornerCircleDistance, cornerCircleRadius, _EdgeSmoothingValue);
#else
                borderValue = max(smoothstep(i.uv.z - _EdgeSmoothingValue, i.uv.z + _EdgeSmoothingValue, distanceToEdge.x),
                                  smoothstep(i.uv.w - _EdgeSmoothingValue, i.uv.w + _EdgeSmoothingValue, distanceToEdge.y));
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
                fixed halfVector = max(0.0, dot(worldNormal, normalize(directionalLightDirection + worldViewDir)));
                fixed specular = saturate(pow(halfVector, _Shininess * pow(_Smoothness, 4.0)) * (_Smoothness * 2.0) * _Metallic);
#else
                fixed specular = 0.0;
#endif
#endif

                // Image based lighting (attempt to mimic the Standard shader).
#if defined(_REFLECTIONS)
                fixed3 worldReflection = reflect(incident, worldNormal);
                fixed4 iblData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, worldReflection, (1.0 - _Smoothness) * UNITY_SPECCUBE_LOD_STEPS);
                fixed3 ibl = DecodeHDR(iblData, unity_SpecCube0_HDR);
#if defined(_REFRACTION)
                fixed4 refractColor = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, refract(incident, worldNormal, _RefractiveIndex));
                ibl *= DecodeHDR(refractColor, unity_SpecCube0_HDR);
#endif
#else
                fixed3 ibl = unity_IndirectSpecColor.rgb;
#endif

                // Fresnel lighting.
#if defined(_FRESNEL)
                fixed fresnel = 1.0 - saturate(abs(dot(worldViewDir, worldNormal)));
#if defined(_RIM_LIGHT)
                fixed3 fresnelColor = _RimColor * pow(fresnel, _RimPower);
#else
                fixed3 fresnelColor = unity_IndirectSpecColor.rgb * (pow(fresnel, _FresnelPower) * max(_Smoothness, 0.5));
#endif
#endif
                // Final lighting mix.
                fixed4 output = albedo;
#if defined(_SPHERICAL_HARMONICS)
                fixed3 ambient = i.ambient;
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
#if defined(_CHANNEL_MAP)
                output.rgb += _EmissiveColor * channel.b;
#else
                output.rgb += _EmissiveColor;
#endif
#endif

                // Inner glow.
#if defined(_INNER_GLOW)
                fixed2 uvGlow = pow(distanceToEdge * _InnerGlowColor.a, _InnerGlowPower);
                output.rgb += lerp(fixed3(0.0, 0.0, 0.0), _InnerGlowColor.rgb, uvGlow.x + uvGlow.y);
#endif

                // Environment coloring.
#if defined(_ENVIRONMENT_COLORING)
                fixed3 environmentColor = incident.x * incident.x * _EnvironmentColorX +
                                          incident.y * incident.y * _EnvironmentColorY +
                                          incident.z * incident.z * _EnvironmentColorZ;
                output.rgb += environmentColor * max(0.0, dot(incident, worldNormal) + _EnvironmentColorThreshold) * _EnvironmentColorIntensity;

#endif

#if defined(_NEAR_PLANE_FADE)
                output *= i.worldPosition.w;
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
