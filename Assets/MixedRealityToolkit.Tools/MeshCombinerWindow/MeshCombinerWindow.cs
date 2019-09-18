// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities.Editor;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Editor
{
    public class MeshCombinerWindow : EditorWindow
    {
        private GameObject targetPrefab = null;
        private MeshCombineSettingsObject settingsObject = null;
        private Vector2 meshFilterScrollPosition = Vector2.zero;
        private Vector2 textureSettingsScrollPosition = Vector2.zero;

        private const int editorGUIIndentAmmount = 2;
        private const int maxMeshFiltersDisplayed = 256;
        private const string meshCombinerWindow_URL = "https://microsoft.github.io/MixedRealityToolkit-Unity/Documentation/Tools/MeshCombinerWindow.html";

        [MenuItem("Mixed Reality Toolkit/Utilities/Mesh Combiner")]
        private static void ShowWindow()
        {
            var window = GetWindow<MeshCombinerWindow>();
            window.settingsObject = CreateInstance<MeshCombineSettingsObject>();
            window.titleContent = new GUIContent("Mesh Combiner", EditorGUIUtility.IconContent("d_Particle Effect").image);
            window.minSize = new Vector2(480.0f, 540.0f);
            window.Show();
        }

        private void OnGUI()
        {
            DrawHeader();

            var settings = settingsObject.Context;
            var settingsSerializedObject = new SerializedObject(settingsObject);

            EditorGUILayout.BeginVertical("Box");
            {
                GUILayout.Label("Import", EditorStyles.boldLabel);

                EditorGUILayout.BeginVertical("Box");
                {
                    targetPrefab = (GameObject)EditorGUILayout.ObjectField("Target Prefab:", targetPrefab, typeof(GameObject), true);
                    AutopopulateMeshFilters();
                }
                EditorGUILayout.EndVertical();

                meshFilterScrollPosition = EditorGUILayout.BeginScrollView(meshFilterScrollPosition);
                {
                    GUI.enabled = false;
                    EditorGUILayout.PropertyField(settingsSerializedObject.FindProperty("Context.MeshFilters"), true);
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

                textureSettingsScrollPosition = EditorGUILayout.BeginScrollView(textureSettingsScrollPosition);
                {
                    EditorGUILayout.PropertyField(settingsSerializedObject.FindProperty("Context.TextureSettings"), true);
                }
                EditorGUILayout.EndScrollView();

                EditorGUILayout.Space();

                EditorGUILayout.BeginVertical("Box");
                {
                    if (GUILayout.Button("Combine Mesh"))
                    {
                        Save(targetPrefab, MeshUtility.CombineModels(settings));
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

            settingsSerializedObject.ApplyModifiedProperties();
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

        private static int CountCombinableMeshes(MeshUtility.MeshCombineSettings settings)
        {
            var count = 0;

            foreach (var meshFilter in settings.MeshFilters)
            {
                if (MeshUtility.CanCombine(meshFilter))
                {
                    ++count;
                }
            }

            return count;
        }

        private void AutopopulateMeshFilters()
        {
            var settings = settingsObject.Context;
            settings.MeshFilters.Clear();

            if (targetPrefab != null)
            {
                var newMeshFilters = targetPrefab.GetComponentsInChildren<MeshFilter>(settings.IncludeInactive);

                foreach (var meshFilter in newMeshFilters)
                {
                    if (MeshUtility.CanCombine(meshFilter))
                    {
                        settings.MeshFilters.Add(meshFilter);
                    }
                }
            }
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

        private static void Save(GameObject targetPrefab, MeshUtility.MeshCombineResult result)
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
                for (var i = 0; i < result.TextureTable.Count; ++i)
                {
                    var pair = result.TextureTable[i];

                    if (pair.Texture != null)
                    {
                        var decompressedTexture = new Texture2D(pair.Texture.width, pair.Texture.height, GetUncompressedEquivalent(pair.Texture.format), true);
                        decompressedTexture.SetPixels(pair.Texture.GetPixels());
                        decompressedTexture.Apply();

                        DestroyImmediate(pair.Texture);

                        var textureData = decompressedTexture.EncodeToTGA();

                        DestroyImmediate(decompressedTexture);

                        var texturePath = AppendToFileName(Path.ChangeExtension(path, ".tga"), pair.Property);
                        File.WriteAllBytes(texturePath, textureData);

                        AssetDatabase.Refresh();

                        result.TextureTable[i] = new MeshUtility.MeshCombineResult.PropertyTexture2DPair()
                        {
                            Property = pair.Property,
                            Texture = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath)
                        };
                    }
                }

                // Save the material.
                foreach (var pair in result.TextureTable)
                {
                    result.Material.SetTexture(pair.Property, pair.Texture);
                }

                AssetDatabase.CreateAsset(result.Material, Path.ChangeExtension(path, ".mat"));

                // Save the result.
                var meshCombineResultObject = CreateInstance<MeshCombineResultObject>();
                meshCombineResultObject.Context = result;
                AssetDatabase.CreateAsset(meshCombineResultObject, AppendToFileName(Path.ChangeExtension(path, ".asset"), "Result"));

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
