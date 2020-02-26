// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Utilities
{
    /// <summary>
    /// Component to animate and visualize a frustum that can be used with 
    /// per pixel based clipping.
    /// </summary>
    [ExecuteInEditMode]
    public class ClippingFrustum : ClippingPrimitive
    {
        [Tooltip("The vertical field of view of the frustum in degrees. ")]
        [SerializeField, Range(0.0f, 89.0f)]
        protected float fieldOfView = 60.0f;

        /// <summary>
        /// The vertical field of view of the frustum in degrees. 
        /// </summary>
        public float FieldOfView
        {
            get => fieldOfView;
            set => fieldOfView = value;
        }

        [Tooltip("The aspect ratio of the frustum (width divided by height).")]
        [SerializeField]
        protected float aspectRatio = 3.0f / 2.0f;

        /// <summary>
        /// The aspect ratio of the frustum (width divided by height).
        /// </summary>
        public float AspectRatio
        {
            get => aspectRatio;
            set => aspectRatio = value;
        }

        [Tooltip("The near clipping plane distance.")]
        [SerializeField, Range(0.0f, 1000.0f)]
        protected float near = 0.3f;

        /// <summary>
        /// The near clipping plane distance.
        /// </summary>
        public float Near
        {
            get => near;
            set => near = value;
        }

        [Tooltip("The far clipping plane distance.")]
        [SerializeField, Range(0.0f, 1000.0f)]
        protected float far = 2.0f;

        /// <summary>
        /// The far clipping plane distance.
        /// </summary>
        public float Far
        {
            get => far;
            set => far = value;
        }

        private int clipFrustumPlanesID;
        private Plane[] frustumPlanes = new Plane[6];

        /// <inheritdoc />
        protected override string Keyword
        {
            get { return "_CLIPPING_FRUSTUM"; }
        }

        /// <inheritdoc />
        protected override string ClippingSideProperty
        {
            get { return "_ClipFrustumSide"; }
        }

        private void OnDrawGizmosSelected()
        {
            if (enabled)
            {
                Gizmos.matrix = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one);
                Gizmos.DrawFrustum(Vector3.zero, FieldOfView, Far, Near, AspectRatio);
            }
        }

        /// <inheritdoc />
        protected override void Initialize()
        {
            base.Initialize();

            clipFrustumPlanesID = Shader.PropertyToID("_ClipFrustumPlanes");
        }

        /// <inheritdoc />
        protected override void UpdateShaderProperties(MaterialPropertyBlock materialPropertyBlock)
        {
            Matrix4x4 worldToPerspective = Matrix4x4.Perspective(FieldOfView, AspectRatio, Near, Far) * Matrix4x4.TRS(-transform.position, transform.rotation, Vector3.one).inverse;
            GeometryUtility.CalculateFrustumPlanes(worldToPerspective, frustumPlanes);
            var planeCount = frustumPlanes.Length;

            Vector4[] planes = new Vector4[planeCount];

            for (var i = 0; i < planeCount; ++i)
            {
                var plane = frustumPlanes[i];
                planes[i] = new Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.distance);
            }

            materialPropertyBlock.SetVectorArray(clipFrustumPlanesID, planes);
        }
    }
}
