// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Utilities
{
    /// <summary>
    /// Component to animate and visualize a pyramid that can be used with 
    /// per pixel based clipping.
    /// </summary>
    [ExecuteInEditMode]
    public class ClippingPyramid : ClippingPrimitive
    {
        private int clipPyramidStartID;
        private int clipPyramidEndID;
        private int clipPyramidEndRadiiID;

        /// <inheritdoc />
        protected override string Keyword
        {
            get { return "_CLIPPING_PYRAMID"; }
        }

        /// <inheritdoc />
        protected override string ClippingSideProperty
        {
            get { return "_ClipPyramidSide"; }
        }

        private void OnDrawGizmosSelected()
        {
            if (enabled)
            {
                Vector3 lossyScale = transform.lossyScale * 0.5f;
                Vector3 start = transform.position + transform.forward * lossyScale.z;
                Vector3 end = transform.position - transform.forward * lossyScale.z;
                Gizmos.matrix = Matrix4x4.TRS(start, transform.rotation, new Vector3(lossyScale.x, lossyScale.x, 0.0f));
                Gizmos.DrawWireSphere(Vector3.zero, 1.0f);
                Gizmos.matrix = Matrix4x4.TRS(end, transform.rotation, new Vector3(lossyScale.y, lossyScale.y, 0.0f));
                Gizmos.DrawWireSphere(Vector3.zero, 1.0f);
                Gizmos.matrix = Matrix4x4.identity;
                Gizmos.DrawLine(start + transform.right * lossyScale.x, end + transform.right * lossyScale.y);
                Gizmos.DrawLine(start - transform.right * lossyScale.x, end - transform.right * lossyScale.y);
                Gizmos.DrawLine(start + transform.up * lossyScale.x, end + transform.up * lossyScale.y);
                Gizmos.DrawLine(start - transform.up * lossyScale.x, end - transform.up * lossyScale.y);
            }
        }

        /// <inheritdoc />
        protected override void Initialize()
        {
            base.Initialize();

            clipPyramidStartID = Shader.PropertyToID("_ClipPyramidStart");
            clipPyramidEndID = Shader.PropertyToID("_ClipPyramidEnd");
            clipPyramidEndRadiiID = Shader.PropertyToID("_ClipPyramidRadii");
        }

        protected override void UpdateShaderProperties(MaterialPropertyBlock materialPropertyBlock)
        {
            Vector3 lossyScale = transform.lossyScale * 0.5f;
            materialPropertyBlock.SetVector(clipPyramidStartID, transform.position + transform.forward * lossyScale.z);
            materialPropertyBlock.SetVector(clipPyramidEndID, transform.position - transform.forward * lossyScale.z);
            materialPropertyBlock.SetVector(clipPyramidEndRadiiID, new Vector2(lossyScale.x, lossyScale.y));
        }
    }
}
