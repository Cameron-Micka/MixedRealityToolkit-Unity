// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

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
        private Vector2 scrollPosition;
        private GameObject autopopulateObject;
        private List<MeshFilter> meshFilters = new List<MeshFilter>();
        private bool includeInactive;
        private bool bakeMaterialColorIntoVertexColor;

        private const int fieldHeight = 38;
        private const string meshCombinerWindow_URL = "https://microsoft.github.io/MixedRealityToolkit-Unity/Documentation/Tools/MeshCombinerWindow.html";

        [MenuItem("Mixed Reality Toolkit/Utilities/Mesh Combiner")]
        private static void ShowWindow()
        {
            MeshCombinerWindow window = GetWindow<MeshCombinerWindow>();
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

                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
                {
                    int newCount = Mathf.Max(2, EditorGUILayout.IntField("Size", meshFilters.Count));

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
                }
                EditorGUILayout.EndScrollView();

                EditorGUILayout.Space();

                EditorGUILayout.BeginVertical("Box");
                {

                    autopopulateObject = (GameObject)EditorGUILayout.ObjectField("Autopopulate from:", autopopulateObject, typeof(GameObject), true);

                    GUI.enabled = autopopulateObject != null;

                    if (GUILayout.Button("Autopopulate"))
                    {
                        Autopopulate();
                    }
                }
                EditorGUILayout.EndVertical();
            }
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical("Box");
            {
                int combinableMeshCount = CountCombinableMeshes();
                GUI.enabled = combinableMeshCount >= 2;

                GUILayout.Label("Export", EditorStyles.boldLabel);

                includeInactive = EditorGUILayout.Toggle("Include Inactive", includeInactive);
                bakeMaterialColorIntoVertexColor = EditorGUILayout.Toggle("Material to Vertex Color", bakeMaterialColorIntoVertexColor);

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

        private bool AllowMeshInstancing()
        {
            return !bakeMaterialColorIntoVertexColor;
        }

        private void Autopopulate()
        {
            meshFilters.Clear();

            var newMeshFilters = autopopulateObject.GetComponentsInChildren<MeshFilter>(includeInactive);
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
            int count = 0;
            foreach (var meshFilter in meshFilters)
            {
                if (CanCombine(meshFilter))
                {
                    ++count;
                }
            }

            return count;
        }

        private Mesh Combine()
        {
            int vertexCount = 0;
            var combineInstances = new List<CombineInstance>();

            foreach (var meshFilter in meshFilters)
            {
                if (!CanCombine(meshFilter))
                {
                    continue;
                }

                var combineInstance = new CombineInstance();
                combineInstance.mesh = AllowMeshInstancing() ? meshFilter.sharedMesh : Instantiate(meshFilter.sharedMesh) as Mesh;

                if (bakeMaterialColorIntoVertexColor)
                {
                    var material = meshFilter.GetComponent<Renderer>().sharedMaterial;

                    if (material != null)
                    {
                        combineInstance.mesh.colors = Enumerable.Repeat(material.color, meshFilter.sharedMesh.vertexCount).ToArray();
                    }
                }

                combineInstance.transform = meshFilter.gameObject.transform.localToWorldMatrix;
                vertexCount += combineInstance.mesh.vertexCount;

                combineInstances.Add(combineInstance);
            }

            if (vertexCount == 0)
            {
                Debug.LogWarning("The MeshCombiner failed to find any meshes to combine.");

                return null;
            }

            var mesh = new Mesh();
            mesh.indexFormat = (vertexCount >= ushort.MaxValue) ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16;
            mesh.CombineMeshes(combineInstances.ToArray(), true, true, false);

            return mesh;
        }

        private void Save(Mesh mesh)
        {
            if (mesh == null)
            {
                return;
            }

            // Save the mesh to disk.
            string path = AssetDatabase.GetAssetPath(autopopulateObject);
            string directory = string.IsNullOrEmpty(path) ? string.Empty : Path.GetDirectoryName(path);
            string filename = string.Format("{0}{1}.asset", string.IsNullOrEmpty(path) ? meshFilters[0].name : Path.GetFileNameWithoutExtension(path), "Combined");

            path = EditorUtility.SaveFilePanelInProject("Save Combined Mesh", filename, "asset", "Please enter a file name to save the mesh to.", directory);

            if (path.Length != 0)
            {
                AssetDatabase.CreateAsset(mesh, path);
                AssetDatabase.SaveAssets();
            }
        }
    }
}
