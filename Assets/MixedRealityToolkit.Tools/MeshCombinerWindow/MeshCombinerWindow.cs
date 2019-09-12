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
        private Vector2 scrollPosition = Vector2.zero;
        private GameObject targetPrefab = null;
        private MeshCombineSettings meshCombineSettings = new MeshCombineSettings();

        [System.Serializable]
        public struct TextureCombineSettings
        {
            public bool Merge;
            public int Resolution;
            public int Padding;
        }

        [System.Serializable]
        public class MeshCombineSettings
        {
            public List<MeshFilter> MeshFilters = new List<MeshFilter>();
            public bool IncludeInactive = false;
            public bool BakeMeshIDIntoUVChannel = true;
            public int MeshIDUVChannel = 3;
            public bool BakeMaterialColorIntoVertexColor = true;
            public TextureCombineSettings MainTexture = new TextureCombineSettings() { Merge = true, Resolution = 2048, Padding = 4 };

            public bool RequiresMaterialData()
            {
                return BakeMaterialColorIntoVertexColor ||
                       MainTexture.Merge;
            }

            public bool AllowsMeshInstancing()
            {
                return !RequiresMaterialData() && 
                       !BakeMeshIDIntoUVChannel;
            }
        }

        public struct MeshCombineResult
        {
            public Mesh Mesh;
            public Texture2D MainTexture;
            public Dictionary<int, int> Mappings;
        }

        private const int editorGUIIndentAmmount = 2;
        private const int maxMeshFiltersDisplayed = 256;
        private const string meshCombinerWindow_URL = "https://microsoft.github.io/MixedRealityToolkit-Unity/Documentation/Tools/MeshCombinerWindow.html";

        [MenuItem("Mixed Reality Toolkit/Utilities/Mesh Combiner")]
        private static void ShowWindow()
        {
            var window = GetWindow<MeshCombinerWindow>();
            window.titleContent = new GUIContent("Mesh Combiner");
            window.minSize = new Vector2(420.0f, 520.0f);
            window.Show();
        }

        private void OnGUI()
        {
            DrawHeader();

            EditorGUILayout.BeginVertical("Box");
            {
                GUILayout.Label("Import", EditorStyles.boldLabel);

                EditorGUILayout.BeginVertical("Box");
                {
                    targetPrefab = (GameObject)EditorGUILayout.ObjectField("Target Prefab:", targetPrefab, typeof(GameObject), true);
                    AutopopulateMeshFilters();
                }
                EditorGUILayout.EndVertical();

                EditorGUILayout.Space();

                GUILayout.Label("Mesh Filters to Combine");

                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
                {
                    GUI.enabled = false;

                    var newCount = Mathf.Max(2, EditorGUILayout.IntField("Size", meshCombineSettings.MeshFilters.Count));

                    while (newCount < meshCombineSettings.MeshFilters.Count)
                    {
                        meshCombineSettings.MeshFilters.RemoveAt(meshCombineSettings.MeshFilters.Count - 1);
                    }

                    while (newCount > meshCombineSettings.MeshFilters.Count)
                    {
                        meshCombineSettings.MeshFilters.Add(null);
                    }

                    var listCount = Mathf.Min(newCount, maxMeshFiltersDisplayed);

                    if (listCount != newCount)
                    {
                        GUILayout.Label(string.Format("Mesh display exceeded, displaying the first {0} meshes.", maxMeshFiltersDisplayed), EditorStyles.helpBox);
                    }

                    for (int i = 0; i < listCount; ++i)
                    {
                        meshCombineSettings.MeshFilters[i] = (MeshFilter)EditorGUILayout.ObjectField("Element " + i, meshCombineSettings.MeshFilters[i], typeof(MeshFilter), true);
                    }

                    GUI.enabled = true;
                }
                EditorGUILayout.EndScrollView();
            }
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical("Box");
            {
                var combinableMeshCount = CountCombinableMeshes();
                GUI.enabled = combinableMeshCount >= 2;

                GUILayout.Label("Export", EditorStyles.boldLabel);

                var previousLabelWidth = EditorGUIUtility.labelWidth;
                var newLabelWidth = EditorGUIUtility.currentViewWidth - 30;

                EditorGUIUtility.labelWidth = newLabelWidth;
                meshCombineSettings.IncludeInactive = EditorGUILayout.Toggle("Include Inactive", meshCombineSettings.IncludeInactive);
                meshCombineSettings.BakeMeshIDIntoUVChannel = EditorGUILayout.Toggle("Bake Mesh ID Into UV Channel", meshCombineSettings.BakeMeshIDIntoUVChannel);
                EditorGUIUtility.labelWidth = previousLabelWidth;

                if (meshCombineSettings.BakeMeshIDIntoUVChannel)
                {
                    EditorGUI.indentLevel += editorGUIIndentAmmount;
                    meshCombineSettings.MeshIDUVChannel = EditorGUILayout.IntSlider("UV Channel", meshCombineSettings.MeshIDUVChannel, 1, 3);
                    EditorGUI.indentLevel -= editorGUIIndentAmmount;
                }

                EditorGUIUtility.labelWidth = newLabelWidth;
                meshCombineSettings.BakeMaterialColorIntoVertexColor = EditorGUILayout.Toggle("Bake Material Color Into Vertex Color", meshCombineSettings.BakeMaterialColorIntoVertexColor);
                meshCombineSettings.MainTexture.Merge = EditorGUILayout.Toggle("Merge Main Textures", meshCombineSettings.MainTexture.Merge);
                EditorGUIUtility.labelWidth = previousLabelWidth;

                if (meshCombineSettings.MainTexture.Merge)
                {
                    EditorGUI.indentLevel += editorGUIIndentAmmount;
                    meshCombineSettings.MainTexture.Resolution = EditorGUILayout.IntSlider("Resolution", meshCombineSettings.MainTexture.Resolution, 2, 4096);
                    meshCombineSettings.MainTexture.Padding = EditorGUILayout.IntSlider("Padding", meshCombineSettings.MainTexture.Padding, 0, 256);
                    EditorGUI.indentLevel -= editorGUIIndentAmmount;
                }

                EditorGUILayout.Space();

                EditorGUILayout.BeginVertical("Box");
                {
                    if (GUILayout.Button("Combine Mesh"))
                    {
                        Save(targetPrefab, meshCombineSettings, MeshCombine(meshCombineSettings));
                    }

                    EditorGUILayout.Space();

                    GUILayout.Box(string.Format("Combinable Mesh Count: {0}", combinableMeshCount), EditorStyles.helpBox, new GUILayoutOption[0]);
                }
                EditorGUILayout.EndVertical();
            }
            EditorGUILayout.EndVertical();
        }

        private static void DrawHeader()
        {
            MixedRealityInspectorUtility.RenderMixedRealityToolkitLogo();

            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUILayout.LabelField("Mixed Reality Toolkit Mesh Combiner Window", EditorStyles.boldLabel);
                InspectorUIUtility.RenderDocumentationButton(meshCombinerWindow_URL);
            }

            EditorGUILayout.LabelField("TODO", EditorStyles.wordWrappedLabel);

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

        private void AutopopulateMeshFilters()
        {
            meshCombineSettings.MeshFilters.Clear();

            if (targetPrefab != null)
            {
                var newMeshFilters = targetPrefab.GetComponentsInChildren<MeshFilter>(meshCombineSettings.IncludeInactive);

                foreach (var meshFilter in newMeshFilters)
                {
                    if (CanCombine(meshFilter))
                    {
                        meshCombineSettings.MeshFilters.Add(meshFilter);
                    }
                }
            }
        }

        private int CountCombinableMeshes()
        {
            var count = 0;

            foreach (var meshFilter in meshCombineSettings.MeshFilters)
            {
                if (CanCombine(meshFilter))
                {
                    ++count;
                }
            }

            return count;
        }

        private static MeshCombineResult MeshCombine(MeshCombineSettings settings)
        {
            var watch = System.Diagnostics.Stopwatch.StartNew();
            var output = new MeshCombineResult();

            var vertexCount = 0;
            var meshID = 0;
            var combineInstances = new List<CombineInstance>();
            var meshCombineInstanceMappings = new Dictionary<int, int>();
            var textureCombineInstanceMappings = new Dictionary<Texture2D, List<CombineInstance>>();
            var texturelessCombineInstances = new List<CombineInstance>();

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

                        if (settings.MainTexture.Merge)
                        {
                            // Map textures to CombineInstances
                            var texture = material.mainTexture as Texture2D;

                            if (texture != null)
                            {
                                List<CombineInstance> combineInstanceMappings;

                                if (textureCombineInstanceMappings.TryGetValue(texture, out combineInstanceMappings))
                                {
                                    combineInstanceMappings.Add(combineInstance);
                                }
                                else
                                {
                                    textureCombineInstanceMappings[texture] = new List<CombineInstance>(new CombineInstance[] { combineInstance });
                                }
                            }
                            else
                            {
                                texturelessCombineInstances.Add(combineInstance);
                            }
                        }
                    }
                }

                combineInstance.transform = meshFilter.gameObject.transform.localToWorldMatrix;
                vertexCount += combineInstance.mesh.vertexCount;

                combineInstances.Add(combineInstance);
                meshCombineInstanceMappings[meshFilter.GetInstanceID()] = meshID;
            }

            if (vertexCount != 0)
            {
                if (settings.MainTexture.Merge && (textureCombineInstanceMappings.Count != 0))
                {
                    // Build a texture atlas of the accumulated textures.
                    var textures = textureCombineInstanceMappings.Keys.ToArray();
                    output.MainTexture = new Texture2D(settings.MainTexture.Resolution, settings.MainTexture.Resolution);
                    var rects = output.MainTexture.PackTextures(textures, settings.MainTexture.Padding, output.MainTexture.width);

                    // Unity's PackTextures method defaults to black for areas that do not contain texture data. Because Unity's material 
                    // system defaults to a white texture for materials that do not have texture specified we need to fill in areas of the 
                    // atlas without texture data to white.
                    FillUnusedPixels(output.MainTexture, rects, Color.white);

                    // Remap the current UVs to their respective rects in the texture atlas.
                    for (var i = 0; i < textures.Length; ++i)
                    {
                        var rect = rects[i];

                        foreach (var combineInstance in textureCombineInstanceMappings[textures[i]])
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

                    // Meshes without a texture should sample the last pixel in the atlas.
                    foreach (var combineInstance in texturelessCombineInstances)
                    {
                        combineInstance.mesh.SetUVs(0, Enumerable.Repeat(new Vector2(1.0f, 1.0f), combineInstance.mesh.vertexCount).ToList());
                    }
                }

                // Perform the mesh combine.
                output.Mesh = new Mesh();
                output.Mesh.indexFormat = (vertexCount >= ushort.MaxValue) ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16;
                output.Mesh.CombineMeshes(combineInstances.ToArray(), true, true, false);
                output.Mappings = meshCombineInstanceMappings;
            }
            else
            {
                Debug.LogWarning("The MeshCombiner failed to find any meshes to combine.");
            }

            Debug.LogFormat("MeshCombine took {0} ms on {1} meshes.", watch.ElapsedMilliseconds, settings.MeshFilters.Count);

            return output;
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

        private static void FillUnusedPixels(Texture2D texture, Rect[] usedRects, Color fillColor)
        {
            var pixels = texture.GetPixels32();
            var width = texture.width;
            var height = texture.height;

            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
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

                    if (!usedPixel)
                    {
                        pixels[(y * width) + x] = fillColor;
                    }
                }
            }

            texture.SetPixels32(pixels);
            texture.Apply();
        }

        private static void Save(GameObject targetPrefab, MeshCombineSettings settings, MeshCombineResult result)
        {
            if (result.Mesh == null)
            {
                return;
            }

            var path = AssetDatabase.GetAssetPath(targetPrefab);
            path = string.IsNullOrEmpty(path) ? PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(targetPrefab) : path;
            var directory = string.IsNullOrEmpty(path) ? string.Empty : Path.GetDirectoryName(path);
            var filename = string.Format("{0}{1}", string.IsNullOrEmpty(path) ? "Mesh" : Path.GetFileNameWithoutExtension(path), "Combined");

            path = EditorUtility.SaveFilePanelInProject("Save Combined Mesh", filename, "prefab", "Please enter a file name to save the mesh to.", directory);

            var watch = System.Diagnostics.Stopwatch.StartNew();

            if (path.Length != 0)
            {
                // Save the mesh.
                AssetDatabase.CreateAsset(result.Mesh, Path.ChangeExtension(path, ".asset"));

                // Save the texture.
                if (result.MainTexture != null)
                {
                    var decompressedTexture = new Texture2D(result.MainTexture.width, result.MainTexture.height, GetUncompressedEquivalent(result.MainTexture.format), true);
                    decompressedTexture.SetPixels(result.MainTexture.GetPixels());
                    decompressedTexture.Apply();

                    DestroyImmediate(result.MainTexture);

                    var textureData = decompressedTexture.EncodeToTGA();

                    DestroyImmediate(decompressedTexture);

                    var texturePath = Path.ChangeExtension(path, ".tga");
                    File.WriteAllBytes(texturePath, textureData);
                    AssetDatabase.Refresh();
                    result.MainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);
                }

                // Save the material.
                var material = new Material(StandardShaderUtility.MrtkStandardShader);

                if (settings.MainTexture.Merge)
                {
                    material.mainTexture = result.MainTexture;
                }

                if (settings.BakeMaterialColorIntoVertexColor)
                {
                    material.EnableKeyword("_VERTEX_COLORS");
                    material.SetFloat("_VertexColors", 1.0f);
                }

                AssetDatabase.CreateAsset(material, Path.ChangeExtension(path, ".mat"));

                // Save the prefab.
                var prefab = new GameObject(filename);
                prefab.AddComponent<MeshFilter>().sharedMesh = result.Mesh;
                prefab.AddComponent<MeshRenderer>().sharedMaterial = material;
                PrefabUtility.SaveAsPrefabAsset(prefab, path);
                AssetDatabase.SaveAssets();

                DestroyImmediate(prefab);
            }

            Debug.LogFormat("MeshCombinerWindow.Save took {0} ms.", watch.ElapsedMilliseconds);
        }
    }
}
