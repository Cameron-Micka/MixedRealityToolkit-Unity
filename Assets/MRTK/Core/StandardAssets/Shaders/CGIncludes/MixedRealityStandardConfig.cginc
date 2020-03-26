// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_CONFIG_INCLUDE
#define MRTK_STANDARD_CONFIG_INCLUDE

// This define will get commented in by the UpgradeShaderForLightweightRenderPipeline method.
//#define _LIGHTWEIGHT_RENDER_PIPELINE

#define IF(a, b, c) lerp(b, c, step((fixed) (a), 0.0)); 

#if defined(_TRIPLANAR_MAPPING) || defined(_DIRECTIONAL_LIGHT) || defined(_SPHERICAL_HARMONICS) || defined(_REFLECTIONS) || defined(_RIM_LIGHT) || defined(_PROXIMITY_LIGHT) || defined(_ENVIRONMENT_COLORING)
#define _NORMAL
#else
#undef _NORMAL
#endif

#if defined(_CLIPPING_PLANE) || defined(_CLIPPING_SPHERE) || defined(_CLIPPING_BOX)
#define _CLIPPING_PRIMITIVE
#else
#undef _CLIPPING_PRIMITIVE
#endif

#if defined(_NORMAL) || defined(_CLIPPING_PRIMITIVE) || defined(_NEAR_PLANE_FADE) || defined(_HOVER_LIGHT) || defined(_PROXIMITY_LIGHT)
#define _WORLD_POSITION
#else
#undef _WORLD_POSITION
#endif

#if defined(_ALPHATEST_ON) || defined(_CLIPPING_PRIMITIVE) || defined(_ROUND_CORNERS)
#define _ALPHA_CLIP
#else
#undef _ALPHA_CLIP
#endif

#if defined(_ALPHABLEND_ON)
#define _TRANSPARENT
#undef _ALPHA_CLIP
#else
#undef _TRANSPARENT
#endif

#if defined(_VERTEX_EXTRUSION) || defined(_ROUND_CORNERS) || defined(_BORDER_LIGHT)
#define _SCALE
#else
#undef _SCALE
#endif

#if defined(_DIRECTIONAL_LIGHT) || defined(_RIM_LIGHT)
#define _FRESNEL
#else
#undef _FRESNEL
#endif

#if defined(_HOVER_LIGHT) || defined(_PROXIMITY_LIGHT)
#define _FLUENT_LIGHT
#else
#undef _FLUENT_LIGHT
#endif

#if defined(_ROUND_CORNERS) || defined(_BORDER_LIGHT) || defined(_INNER_GLOW)
#define _DISTANCE_TO_EDGE
#else
#undef _DISTANCE_TO_EDGE
#endif

#if !defined(_DISABLE_ALBEDO_MAP) || defined(_TRIPLANAR_MAPPING) || defined(_CHANNEL_MAP) || defined(_NORMAL_MAP) || defined(_DISTANCE_TO_EDGE) || defined(_IRIDESCENCE)
#define _UV
#else
#undef _UV
#endif

#endif // MRTK_STANDARD_MAIN_INCLUDE
