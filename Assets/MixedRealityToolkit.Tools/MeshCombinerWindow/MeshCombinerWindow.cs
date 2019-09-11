// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities;
using Microsoft.MixedReality.Toolkit.Utilities.Editor;
using System;
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
        private List<MeshFilter> meshFilters = new List<MeshFilter>();
        private bool includeInactive = false;
        private bool bakeMaterialColorIntoVertexColor = false;
        private bool mergeMainTextures = true;

        private struct MeshCombineResult
        {
            public Mesh mesh;
            public Texture2D mainTexture;
        }

        private const string meshCombinerWindow_URL = "https://microsoft.github.io/MixedRealityToolkit-Unity/Documentation/Tools/MeshCombinerWindow.html";

        [MenuItem("Mixed Reality Toolkit/Utilities/Mesh Combiner")]
        private static void ShowWindow()
        {
            var window = GetWindow<MeshCombinerWindow>();
            window.titleContent = new GUIContent("Mesh Combiner");
            window.minSize = new Vector2(380.0f, 400.0f);
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

                    if (targetPrefab != null)
                    {
                        AutopopulateMeshFilters();
                    }
                }
                EditorGUILayout.EndVertical();

                EditorGUILayout.Space();

                GUILayout.Label("Mesh Filters to Combine");

                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
                {
                    GUI.enabled = false;

                    var newCount = Mathf.Max(2, EditorGUILayout.IntField("Size", meshFilters.Count));

                    while (newCount < meshFilters.Count)
                    {
                        meshFilters.RemoveAt(meshFilters.Count - 1);
                    }

                    while (newCount > meshFilters.Count)
                    {
                        meshFilters.Add(null);
                    }

                    for (int i = 0; i < meshFilters.Count; ++i)
                    {
                        meshFilters[i] = (MeshFilter)EditorGUILayout.ObjectField("Element " + i, meshFilters[i], typeof(MeshFilter), true);
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

                includeInactive = EditorGUILayout.Toggle("Include Inactive", includeInactive);
                bakeMaterialColorIntoVertexColor = EditorGUILayout.Toggle("Bake Vertex Colors", bakeMaterialColorIntoVertexColor);
                mergeMainTextures = EditorGUILayout.Toggle("Merge Main Textures", mergeMainTextures);

                if (GUILayout.Button("Save Mesh"))
                {
                    Save(Combine());
                }

                EditorGUILayout.Space();

                GUILayout.Box(string.Format("Combinable Mesh Count: {0}", combinableMeshCount), EditorStyles.helpBox, new GUILayoutOption[0]);
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

        private bool CanCombine(MeshFilter meshFilter)
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

        private bool RequiresMaterialData()
        {
            return bakeMaterialColorIntoVertexColor ||
                   mergeMainTextures;
        }

        private bool AllowMeshInstancing()
        {
            return !RequiresMaterialData();
        }

        private void AutopopulateMeshFilters()
        {
            meshFilters.Clear();

            var newMeshFilters = targetPrefab.GetComponentsInChildren<MeshFilter>(includeInactive);
            foreach (var meshFilter in newMeshFilters)
            {
                if (CanCombine(meshFilter))
                {
                    meshFilters.Add(meshFilter);
                }
            }
        }

        private int CountCombinableMeshes()
        {
            var count = 0;
            foreach (var meshFilter in meshFilters)
            {
                if (CanCombine(meshFilter))
                {
                    ++count;
                }
            }

            return count;
        }

        private MeshCombineResult Combine()
        {
            MeshCombineResult output = new MeshCombineResult();

            var vertexCount = 0;
            var combineInstances = new List<CombineInstance>();
            var textureCombineInstanceMappings = new Dictionary<Texture2D, List<CombineInstance>>();

            foreach (var meshFilter in meshFilters)
            {
                if (!CanCombine(meshFilter))
                {
                    continue;
                }

                var combineInstance = new CombineInstance();
                combineInstance.mesh = AllowMeshInstancing() ? meshFilter.sharedMesh : Instantiate(meshFilter.sharedMesh) as Mesh;

                if (RequiresMaterialData())
                {
                    var material = meshFilter.GetComponent<Renderer>()?.sharedMaterial;

                    if (material != null)
                    {
                        if (bakeMaterialColorIntoVertexColor)
                        {
                            combineInstance.mesh.colors = Enumerable.Repeat(material.color, meshFilter.sharedMesh.vertexCount).ToArray();
                        }

                        if (mergeMainTextures)
                        {
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
                        }
                    }
                }

                combineInstance.transform = meshFilter.gameObject.transform.localToWorldMatrix;
                vertexCount += combineInstance.mesh.vertexCount;

                combineInstances.Add(combineInstance);
            }

            if (vertexCount == 0)
            {
                Debug.LogWarning("The MeshCombiner failed to find any meshes to combine.");

                return output;
            }

            if (textureCombineInstanceMappings.Count != 0)
            {
                var textures = textureCombineInstanceMappings.Keys.ToArray();
                output.mainTexture = new Texture2D(2048, 2048);
                var rects = output.mainTexture.PackTextures(textures, 2, 2048, false);

                for (int i = 0; i < textures.Length; ++i)
                {
                    var rect = rects[i];

                    foreach (var combineInstance in textureCombineInstanceMappings[textures[i]])
                    {
                        List<Vector2> uvs = new List<Vector2>();
                        combineInstance.mesh.GetUVs(0, uvs);
                        List<Vector2> remappedUvs = new List<Vector2>(uvs.Count);

                        for (int j = 0; j < uvs.Count; ++j)
                        {
                            remappedUvs.Add(new Vector2(Mathf.Lerp(rect.xMin, rect.xMax, uvs[j].x), 
                                                        Mathf.Lerp(rect.yMin, rect.yMax, uvs[j].y)));
                        }

                        combineInstance.mesh.SetUVs(0, remappedUvs);
                    }
                }
            }

            output.mesh = new Mesh();
            output.mesh.indexFormat = (vertexCount >= ushort.MaxValue) ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16;
            output.mesh.CombineMeshes(combineInstances.ToArray(), true, true, false);

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

        private void Save(MeshCombineResult result)
        {
            if (result.mesh == null)
            {
                return;
            }

            // Save the mesh to disk.
            var path = AssetDatabase.GetAssetPath(targetPrefab);
            var directory = string.IsNullOrEmpty(path) ? string.Empty : Path.GetDirectoryName(path);
            var filename = string.Format("{0}{1}", string.IsNullOrEmpty(path) ? meshFilters[0].name : Path.GetFileNameWithoutExtension(path), "Combined");

            path = EditorUtility.SaveFilePanelInProject("Save Combined Mesh", filename, "prefab", "Please enter a file name to save the mesh to.", directory);

            if (path.Length != 0)
            {
                // Save the mesh.
                AssetDatabase.CreateAsset(result.mesh, Path.ChangeExtension(path, ".asset"));

                // Save the texture.
                if (result.mainTexture != null)
                {
                    var decompressedTexture = new Texture2D(result.mainTexture.width, result.mainTexture.height, GetUncompressedEquivalent(result.mainTexture.format), true);
                    decompressedTexture.SetPixels(result.mainTexture.GetPixels());
                    decompressedTexture.Apply();

                    DestroyImmediate(result.mainTexture);

                    var textureData = decompressedTexture.EncodeToTGA();

                    DestroyImmediate(decompressedTexture);

                    var texturePath = Path.ChangeExtension(path, ".tga");
                    File.WriteAllBytes(texturePath, textureData);
                    AssetDatabase.Refresh();
                    result.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);
                }

                // Save the material.
                var material = new Material(StandardShaderUtility.MrtkStandardShader);
                material.mainTexture = result.mainTexture;
                AssetDatabase.CreateAsset(material, Path.ChangeExtension(path, ".mat"));

                // Save the prefab.
                var prefab = new GameObject(filename);
                prefab.AddComponent<MeshFilter>().sharedMesh = result.mesh;
                prefab.AddComponent<MeshRenderer>().sharedMaterial = material;
                PrefabUtility.SaveAsPrefabAsset(prefab, path);

                AssetDatabase.SaveAssets();
            }
        }
    }
}
