// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities;
using Microsoft.MixedReality.Toolkit.Utilities.Editor;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Editor
{
    public class MeshCombinerWindow : EditorWindow
    {
        public class MeshCombineSettings : ScriptableObject
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

        public class MeshCombineResult
        {
            public Mesh Mesh = null;
            public Material Material = null;
            public Dictionary<string, Texture2D> Textures = new Dictionary<string, Texture2D>();
            public Dictionary<int, int> MeshIDMappings = new Dictionary<int, int>();
        }

        private Vector2 scrollPosition = Vector2.zero;
        private GameObject targetPrefab = null;
        private MeshCombineSettings settings = null;

        private const int editorGUIIndentAmmount = 2;
        private const int maxMeshFiltersDisplayed = 256;
        private const string meshCombinerWindow_URL = "https://microsoft.github.io/MixedRealityToolkit-Unity/Documentation/Tools/MeshCombinerWindow.html";

        [MenuItem("Mixed Reality Toolkit/Utilities/Mesh Combiner")]
        private static void ShowWindow()
        {
            var window = GetWindow<MeshCombinerWindow>();
            window.settings = CreateInstance<MeshCombineSettings>();
            window.titleContent = new GUIContent("Mesh Combiner", EditorGUIUtility.IconContent("d_Particle Effect").image);
            window.minSize = new Vector2(480.0f, 640.0f);
            window.Show();
        }

        private void OnGUI()
        {
            DrawHeader();

            var settingsObject = new SerializedObject(settings);

            EditorGUILayout.BeginVertical("Box");
            {
                GUILayout.Label("Import", EditorStyles.boldLabel);

                EditorGUILayout.BeginVertical("Box");
                {
                    targetPrefab = (GameObject)EditorGUILayout.ObjectField("Target Prefab:", targetPrefab, typeof(GameObject), true);
                    AutopopulateMeshFilters();
                }
                EditorGUILayout.EndVertical();

                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
                {
                    GUI.enabled = false;
                    EditorGUILayout.PropertyField(settingsObject.FindProperty("MeshFilters"), true);
                    GUI.enabled = true;
                }
                EditorGUILayout.EndScrollView();
            }
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical("Box");
            {
                var combinableMeshCount = CountCombinableMeshes(settings);
                var canCombineMeshes = combinableMeshCount >= 2;

                GUI.enabled = canCombineMeshes;

                GUILayout.Label("Export", EditorStyles.boldLabel);

                var previousLabelWidth = EditorGUIUtility.labelWidth;
                var newLabelWidth = EditorGUIUtility.currentViewWidth - 32;

                EditorGUIUtility.labelWidth = newLabelWidth;
                settings.IncludeInactive = EditorGUILayout.Toggle("Include Inactive", settings.IncludeInactive);
                settings.BakeMeshIDIntoUVChannel = EditorGUILayout.Toggle("Bake Mesh ID Into UV Channel", settings.BakeMeshIDIntoUVChannel);
                EditorGUIUtility.labelWidth = previousLabelWidth;

                if (settings.BakeMeshIDIntoUVChannel)
                {
                    EditorGUI.indentLevel += editorGUIIndentAmmount;
                    settings.MeshIDUVChannel = EditorGUILayout.IntSlider("UV Channel", settings.MeshIDUVChannel, 1, 3);
                    EditorGUI.indentLevel -= editorGUIIndentAmmount;
                }

                EditorGUIUtility.labelWidth = newLabelWidth;
                settings.BakeMaterialColorIntoVertexColor = EditorGUILayout.Toggle("Bake Material Color Into Vertex Color", settings.BakeMaterialColorIntoVertexColor);
                EditorGUIUtility.labelWidth = previousLabelWidth;

                EditorGUILayout.PropertyField(settingsObject.FindProperty("TextureSettings"), true);

                EditorGUILayout.Space();

                EditorGUILayout.BeginVertical("Box");
                {
                    if (GUILayout.Button("Combine Mesh"))
                    {
                        Save(targetPrefab, CombineModels(settings));
                    }

                    EditorGUILayout.Space();

                    if (!canCombineMeshes)
                    {
                        EditorGUILayout.HelpBox("Please select at least 2 Mesh Filters to combine.", MessageType.Info);
                    }
                    else
                    {
                        GUILayout.Box(string.Format("Combinable Mesh Count: {0}", combinableMeshCount), EditorStyles.helpBox, new GUILayoutOption[0]);
                    }
                }
                EditorGUILayout.EndVertical();
            }
            EditorGUILayout.EndVertical();

            settingsObject.ApplyModifiedProperties();
        }

        private static void DrawHeader()
        {
            MixedRealityInspectorUtility.RenderMixedRealityToolkitLogo();

            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUILayout.LabelField("Mixed Reality Toolkit Mesh Combiner Window", EditorStyles.boldLabel);
                InspectorUIUtility.RenderDocumentationButton(meshCombinerWindow_URL);
            }

            EditorGUILayout.LabelField("This tool automatically combines meshes and materials to help reduce scene complexity and draw call count.", EditorStyles.wordWrappedLabel);

            EditorGUILayout.Space();
        }

        private static bool CanCombine(MeshFilter meshFilter)
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

        private static int CountCombinableMeshes(MeshCombineSettings settings)
        {
            var count = 0;

            foreach (var meshFilter in settings.MeshFilters)
            {
                if (CanCombine(meshFilter))
                {
                    ++count;
                }
            }

            return count;
        }

        private void AutopopulateMeshFilters()
        {
            settings.MeshFilters.Clear();

            if (targetPrefab != null)
            {
                var newMeshFilters = targetPrefab.GetComponentsInChildren<MeshFilter>(settings.IncludeInactive);

                foreach (var meshFilter in newMeshFilters)
                {
                    if (CanCombine(meshFilter))
                    {
                        settings.MeshFilters.Add(meshFilter);
                    }
                }
            }
        }

        public static MeshCombineResult CombineModels(MeshCombineSettings settings)
        {
            var watch = System.Diagnostics.Stopwatch.StartNew();
            var output = new MeshCombineResult();

            var combineInstances = new List<CombineInstance>();
            var combineInstancesToIDMappings = new Dictionary<int, int>();

            var textureToCombineInstanceMappings = new List<Dictionary<Texture2D, List<CombineInstance>>>(settings.TextureSettings.Count);
            var texturelessCombineInstances = new List<List<CombineInstance>>();

            foreach (var textureSetting in settings.TextureSettings)
            {
                textureToCombineInstanceMappings.Add(new Dictionary<Texture2D, List<CombineInstance>>());
                texturelessCombineInstances.Add(new List<CombineInstance>());
            }

            var vertexCount = GatherCombineData(settings, combineInstances, combineInstancesToIDMappings, textureToCombineInstanceMappings, texturelessCombineInstances);

            if (vertexCount != 0)
            {
                output.Textures = CombineTextures(settings, textureToCombineInstanceMappings, texturelessCombineInstances);
                output.Mesh = CombineMeshes(combineInstances, vertexCount);
                output.Material = CombineMaterials(settings, output.Textures);
                output.MeshIDMappings = combineInstancesToIDMappings;
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
                                             Dictionary<int, int> combineInstancesToIDMappings, 
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
                combineInstance.mesh = settings.AllowsMeshInstancing() ? meshFilter.sharedMesh : Instantiate(meshFilter.sharedMesh) as Mesh;

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
                combineInstancesToIDMappings[meshFilter.GetInstanceID()] = meshID;
            }

            return vertexCount;
        }

        private static Dictionary<string, Texture2D> CombineTextures(MeshCombineSettings settings,
                                                                     List<Dictionary<Texture2D, List<CombineInstance>>> textureToCombineInstanceMappings,
                                                                     List<List<CombineInstance>> texturelessCombineInstances)
        {
            var output = new Dictionary<string, Texture2D>();
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
                    output.Add(textureSetting.TextureProperty, atlas);
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

        private static Material CombineMaterials(MeshCombineSettings settings, Dictionary<string, Texture2D> textures)
        {
            var output = new Material(StandardShaderUtility.MrtkStandardShader);

            if (settings.BakeMaterialColorIntoVertexColor)
            {
                output.EnableKeyword("_VERTEX_COLORS");
                output.SetFloat("_VertexColors", 1.0f);
            }

            foreach (var texture in textures)
            {
                if (texture.Value != null)
                {
                    output.SetTexture(texture.Key, texture.Value);

                    if (texture.Key == "_NormalMap")
                    {
                        output.EnableKeyword("_NORMAL_MAP");
                        output.SetFloat("_EnableNormalMap", 1.0f);
                    }
                }
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

        private static TextureFormat GetUncompressedEquivalent(TextureFormat format)
        {
            switch (format)
            {
                case TextureFormat.DXT1:
                case TextureFormat.DXT1Crunched:
                    {
                        return TextureFormat.RGB24;
                    }
                case TextureFormat.DXT5:
                case TextureFormat.DXT5Crunched:
                default:
                    {
                        return TextureFormat.RGBA32;
                    }
            }
        }

        private static string AppendToFileName(string source, string appendValue)
        {
            return $"{Path.Combine(Path.GetDirectoryName(source), Path.GetFileNameWithoutExtension(source))}{appendValue}{Path.GetExtension(source)}";
        }

        private static void Save(GameObject targetPrefab, MeshCombineResult result)
        {
            if (result.Mesh == null)
            {
                return;
            }

            var path = AssetDatabase.GetAssetPath(targetPrefab);
            path = string.IsNullOrEmpty(path) ? PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(targetPrefab) : path;
            var directory = string.IsNullOrEmpty(path) ? string.Empty : Path.GetDirectoryName(path);
            var filename = string.Format("{0}{1}", string.IsNullOrEmpty(path) ? "Mesh" : Path.GetFileNameWithoutExtension(path), "Combined");

            path = EditorUtility.SaveFilePanelInProject("Save Combined Mesh", filename, "prefab", "Please enter a file name.", directory);

            var watch = System.Diagnostics.Stopwatch.StartNew();

            if (path.Length != 0)
            {
                // Save the mesh.
                AssetDatabase.CreateAsset(result.Mesh, Path.ChangeExtension(path, ".asset"));

                // Save the textures.
                var textureAssets = new Dictionary<string, Texture2D>();

                foreach (var texture in result.Textures)
                {
                    var decompressedTexture = new Texture2D(texture.Value.width, texture.Value.height, GetUncompressedEquivalent(texture.Value.format), true);
                    decompressedTexture.SetPixels(texture.Value.GetPixels());
                    decompressedTexture.Apply();

                    DestroyImmediate(texture.Value);

                    var textureData = decompressedTexture.EncodeToTGA();

                    DestroyImmediate(decompressedTexture);

                    var texturePath = AppendToFileName(Path.ChangeExtension(path, ".tga"), texture.Key);
                    File.WriteAllBytes(texturePath, textureData);
                    AssetDatabase.Refresh();
                    textureAssets.Add(texture.Key, AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath));
                }

                // Save the material.
                foreach (var texture in textureAssets)
                {
                    result.Material.SetTexture(texture.Key, texture.Value);
                }

                var materialPath = Path.ChangeExtension(path, ".mat");
                AssetDatabase.CreateAsset(result.Material, materialPath);

                // Save the prefab.
                var prefab = new GameObject(filename);
                prefab.AddComponent<MeshFilter>().sharedMesh = result.Mesh;
                prefab.AddComponent<MeshRenderer>().sharedMaterial = result.Material;
                Selection.activeGameObject = PrefabUtility.SaveAsPrefabAsset(prefab, path);
                DestroyImmediate(prefab);
                AssetDatabase.SaveAssets();

                Debug.LogFormat("Saved combined mesh to: {0}", path);
            }

            Debug.LogFormat("MeshCombinerWindow.Save took {0} ms.", watch.ElapsedMilliseconds);
        }
    }
}
