﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Editor
{
    public static class MeshUtility
    {
        [System.Serializable]
        public class MeshCombineResult
        {
            public Mesh Mesh = null;
            public Material Material = null;

            [System.Serializable]
            public struct PropertyTexture2DPair
            {
                public string Property;
                public Texture2D Texture;
            }

            public List<PropertyTexture2DPair> TextureTable = new List<PropertyTexture2DPair>();

            [System.Serializable]
            public struct MeshIDPair
            {
                public Mesh Mesh;
                public int VertexAttributeID;
            }

            public List<MeshIDPair> MeshIDTable = new List<MeshIDPair>();
        }

        [System.Serializable]
        public class MeshCombineSettings
        {
            public List<MeshFilter> MeshFilters = new List<MeshFilter>();
            public bool IncludeInactive = false;
            public bool BakeMeshIDIntoUVChannel = true;
            public int MeshIDUVChannel = 3;
            public bool BakeMaterialColorIntoVertexColor = true;

            public enum TextureUsage
            {
                Color = 0,
                Normal = 1
            }

            public static readonly Color[] TextureUsageDefault = new Color[]
            {
                new Color(1.0f, 1.0f, 1.0f, 1.0f),
                new Color(0.498f, 0.498f, 1.0f, 1.0f)
            };

            [System.Serializable]
            public class TextureSetting
            {
                public string TextureProperty = "Name";
                public TextureUsage Usage = TextureUsage.Color;
                [Range(2, 4096)]
                public int Resolution = 2048;
                [Range(0, 256)]
                public int Padding = 4;
            }

            public List<TextureSetting> TextureSettings = new List<TextureSetting>()
            {
                new TextureSetting() { TextureProperty = "_MainTex", Usage = TextureUsage.Color, Resolution = 2048, Padding = 4 },
                new TextureSetting() { TextureProperty = "_NormalMap", Usage = TextureUsage.Normal, Resolution = 2048, Padding = 4 }
            };

            public bool RequiresMaterialData()
            {
                if (BakeMaterialColorIntoVertexColor)
                {
                    return true;
                }

                return TextureSettings.Count != 0;
            }

            public bool AllowsMeshInstancing()
            {
                return !RequiresMaterialData() &&
                       !BakeMeshIDIntoUVChannel;
            }
        }

        public static bool CanCombine(MeshFilter meshFilter)
        {
            if (meshFilter == null)
            {
                return false;
            }

            if (meshFilter.sharedMesh == null)
            {
                return false;
            }

            if (meshFilter.sharedMesh.vertexCount == 0)
            {
                return false;
            }

            var renderer = meshFilter.GetComponent<Renderer>();

            if (renderer is SkinnedMeshRenderer)
            {
                // Don't merge skinned meshes.
                return false;
            }

            return true;
        }

        public static MeshCombineResult CombineModels(MeshCombineSettings settings)
        {
            var watch = System.Diagnostics.Stopwatch.StartNew();
            var output = new MeshCombineResult();

            var combineInstances = new List<CombineInstance>();
            var meshIDTable = new List<MeshCombineResult.MeshIDPair>();

            var textureToCombineInstanceMappings = new List<Dictionary<Texture2D, List<CombineInstance>>>(settings.TextureSettings.Count);
            var texturelessCombineInstances = new List<List<CombineInstance>>();

            foreach (var textureSetting in settings.TextureSettings)
            {
                textureToCombineInstanceMappings.Add(new Dictionary<Texture2D, List<CombineInstance>>());
                texturelessCombineInstances.Add(new List<CombineInstance>());
            }

            var vertexCount = GatherCombineData(settings, combineInstances, meshIDTable, textureToCombineInstanceMappings, texturelessCombineInstances);

            if (vertexCount != 0)
            {
                output.TextureTable = CombineTextures(settings, textureToCombineInstanceMappings, texturelessCombineInstances);
                output.Mesh = CombineMeshes(combineInstances, vertexCount);
                output.Material = CombineMaterials(settings, output.TextureTable);
                output.MeshIDTable = meshIDTable;
            }
            else
            {
                Debug.LogWarning("The MeshCombiner failed to find any meshes to combine.");
            }

            Debug.LogFormat("MeshCombine took {0} ms on {1} meshes.", watch.ElapsedMilliseconds, settings.MeshFilters.Count);

            return output;
        }

        private static uint GatherCombineData(MeshCombineSettings settings,
                                             List<CombineInstance> combineInstances,
                                             List<MeshCombineResult.MeshIDPair> meshIDTable,
                                             List<Dictionary<Texture2D, List<CombineInstance>>> textureToCombineInstanceMappings,
                                             List<List<CombineInstance>> texturelessCombineInstances)
        {
            var meshID = 0;
            var vertexCount = 0U;

            // Create a CombineInstance for each mesh filter.
            foreach (var meshFilter in settings.MeshFilters)
            {
                if (!CanCombine(meshFilter))
                {
                    continue;
                }

                var combineInstance = new CombineInstance();
                combineInstance.mesh = settings.AllowsMeshInstancing() ? meshFilter.sharedMesh : Object.Instantiate(meshFilter.sharedMesh) as Mesh;

                if (settings.BakeMeshIDIntoUVChannel)
                {
                    // Write the MeshID to each a UV channel.
                    ++meshID;
                    combineInstance.mesh.SetUVs(settings.MeshIDUVChannel, Enumerable.Repeat(new Vector2(meshID, 0.0f), combineInstance.mesh.vertexCount).ToList());
                }

                if (settings.RequiresMaterialData())
                {
                    var material = meshFilter.GetComponent<Renderer>()?.sharedMaterial;

                    if (material != null)
                    {
                        if (settings.BakeMaterialColorIntoVertexColor)
                        {
                            // Write the material color to all vertex colors.
                            combineInstance.mesh.colors = Enumerable.Repeat(material.color, combineInstance.mesh.vertexCount).ToArray();
                        }

                        var textureSettingIndex = 0;

                        foreach (var textureSetting in settings.TextureSettings)
                        {
                            // Map textures to CombineInstances
                            var texture = material.GetTexture(textureSetting.TextureProperty) as Texture2D;

                            if (texture != null)
                            {
                                List<CombineInstance> combineInstanceMappings;

                                if (textureToCombineInstanceMappings[textureSettingIndex].TryGetValue(texture, out combineInstanceMappings))
                                {
                                    combineInstanceMappings.Add(combineInstance);
                                }
                                else
                                {
                                    textureToCombineInstanceMappings[textureSettingIndex][texture] = new List<CombineInstance>(new CombineInstance[] { combineInstance });
                                }
                            }
                            else
                            {
                                texturelessCombineInstances[textureSettingIndex].Add(combineInstance);
                            }

                            ++textureSettingIndex;
                        }
                    }
                }

                combineInstance.transform = meshFilter.gameObject.transform.localToWorldMatrix;
                vertexCount += (uint)combineInstance.mesh.vertexCount;

                combineInstances.Add(combineInstance);
                meshIDTable.Add(new MeshCombineResult.MeshIDPair() { Mesh = meshFilter.sharedMesh, VertexAttributeID = meshID });
            }

            return vertexCount;
        }

        private static List<MeshCombineResult.PropertyTexture2DPair> CombineTextures(MeshCombineSettings settings,
                                                                             List<Dictionary<Texture2D, List<CombineInstance>>> textureToCombineInstanceMappings,
                                                                             List<List<CombineInstance>> texturelessCombineInstances)
        {
            var output = new List<MeshCombineResult.PropertyTexture2DPair>();
            var uvsAltered = false;
            var textureSettingIndex = 0;

            foreach (var textureSetting in settings.TextureSettings)
            {
                var mapping = textureToCombineInstanceMappings[textureSettingIndex];

                if (mapping.Count != 0)
                {
                    // Build a texture atlas of the accumulated textures.
                    var textures = mapping.Keys.ToArray();
                    var atlas = new Texture2D(textureSetting.Resolution, textureSetting.Resolution);
                    output.Add(new MeshCombineResult.PropertyTexture2DPair() { Property = textureSetting.TextureProperty, Texture = atlas });
                    var rects = atlas.PackTextures(textures, textureSetting.Padding, textureSetting.Resolution);
                    PostprocessTexture(atlas, rects, textureSetting.Usage);

                    if (!uvsAltered)
                    {
                        // Remap the current UVs to their respective rects in the texture atlas.
                        for (var i = 0; i < textures.Length; ++i)
                        {
                            var rect = rects[i];

                            foreach (var combineInstance in mapping[textures[i]])
                            {
                                var uvs = new List<Vector2>();
                                combineInstance.mesh.GetUVs(0, uvs);
                                var remappedUvs = new List<Vector2>(uvs.Count);

                                for (var j = 0; j < uvs.Count; ++j)
                                {
                                    remappedUvs.Add(new Vector2(Mathf.Lerp(rect.xMin, rect.xMax, uvs[j].x),
                                                                Mathf.Lerp(rect.yMin, rect.yMax, uvs[j].y)));
                                }

                                combineInstance.mesh.SetUVs(0, remappedUvs);
                            }
                        }
                    }
                }

                if (!uvsAltered)
                {
                    // Meshes without a texture should sample the last pixel in the atlas.
                    foreach (var combineInstance in texturelessCombineInstances[textureSettingIndex])
                    {
                        combineInstance.mesh.SetUVs(0, Enumerable.Repeat(new Vector2(1.0f, 1.0f), combineInstance.mesh.vertexCount).ToList());
                    }
                }

                uvsAltered = true;
                ++textureSettingIndex;
            }

            return output;
        }

        private static Mesh CombineMeshes(List<CombineInstance> combineInstances, uint vertexCount)
        {
            var output = new Mesh();
            output.indexFormat = (vertexCount >= ushort.MaxValue) ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16;
            output.CombineMeshes(combineInstances.ToArray(), true, true, false);

            return output;
        }

        private static Material CombineMaterials(MeshCombineSettings settings, List<MeshCombineResult.PropertyTexture2DPair> textureTable)
        {
            var output = new Material(StandardShaderUtility.MrtkStandardShader);

            if (settings.BakeMaterialColorIntoVertexColor)
            {
                output.EnableKeyword("_VERTEX_COLORS");
                output.SetFloat("_VertexColors", 1.0f);
            }

            var textureSettingIndex = 0;

            foreach (var pair in textureTable)
            {
                if (pair.Texture != null)
                {
                    output.SetTexture(pair.Property, pair.Texture);

                    if (settings.TextureSettings[textureSettingIndex].Usage == MeshCombineSettings.TextureUsage.Normal)
                    {
                        output.EnableKeyword("_NORMAL_MAP");
                        output.SetFloat("_EnableNormalMap", 1.0f);
                    }
                }

                ++textureSettingIndex;
            }

            return output;
        }

        private static void PostprocessTexture(Texture2D texture, Rect[] usedRects, MeshCombineSettings.TextureUsage usage)
        {
            var pixels = texture.GetPixels();
            var width = texture.width;
            var height = texture.height;

            for (var y = 0; y < height; ++y)
            {
                for (var x = 0; x < width; ++x)
                {
                    var usedPixel = false;
                    var position = new Vector2((float)x / width, (float)y / height);

                    foreach (var rect in usedRects)
                    {
                        if (rect.Contains(position))
                        {
                            usedPixel = true;
                            break;
                        }
                    }

                    if (usedPixel)
                    {
                        if (usage == MeshCombineSettings.TextureUsage.Normal)
                        {
                            // Apply Unity's UnpackNormalDXT5nm method to go from DXTnm to RGB.
                            var c = pixels[(y * width) + x];
                            c.r = c.a;
                            Vector2 normal = new Vector2(c.r, c.g);
                            c.b = (Mathf.Sqrt(1.0f - Mathf.Clamp01(Vector2.Dot(normal, normal))) * 0.5f) + 0.5f;
                            pixels[(y * width) + x] = c;
                        }
                    }
                    else
                    {
                        // Unity's PackTextures method defaults to black for areas that do not contain texture data. Because Unity's material 
                        // system defaults to a white texture for color textures (and a 'suitable' normal for normal textures) that do not have texture 
                        // specified, we need to fill in areas of the atlas with appropriate defaults.
                        pixels[(y * width) + x] = MeshCombineSettings.TextureUsageDefault[(int)usage];
                    }
                }
            }

            texture.SetPixels(pixels);
            texture.Apply();
        }
    }
}
