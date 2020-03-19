// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_PASS_META_INCLUDE
#define MRTK_STANDARD_PASS_META_INCLUDE

            #include "UnityCG.cginc"
            #include "UnityMetaPass.cginc"

            // This define will get commented in by the UpgradeShaderForLightweightRenderPipeline method.
            //#define _LIGHTWEIGHT_RENDER_PIPELINE

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 _MainTex_ST;

            v2f vert(appdata_full v)
            {
                v2f o;
                o.vertex = UnityMetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord2.xy, unity_LightmapST, unity_DynamicLightmapST);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            sampler2D _MainTex;
            sampler2D _ChannelMap;

            fixed4 _Color;
            fixed4 _EmissiveColor;

#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
            CBUFFER_START(_LightBuffer)
            float4 _MainLightPosition;
            half4 _MainLightColor;
            CBUFFER_END
#else
            fixed4 _LightColor0;
#endif

            half4 frag(v2f i) : SV_Target
            {
                UnityMetaInput output;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, output);

                output.Albedo = tex2D(_MainTex, i.uv) * _Color;
#if defined(_EMISSION)
#if defined(_CHANNEL_MAP)
                output.Emission += tex2D(_ChannelMap, i.uv).b * _EmissiveColor;
#else
                output.Emission += _EmissiveColor;
#endif
#endif
#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
                output.SpecularColor = _MainLightColor.rgb;
#else
                output.SpecularColor = _LightColor0.rgb;
#endif

                return UnityMetaFragment(output);
            }

#endif // MRTK_STANDARD_PASS_META_INCLUDE
