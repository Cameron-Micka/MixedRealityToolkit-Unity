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
        private int clipPyramidHeightID;
        private int clipPyramidInverseTransformID;

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
                Vector3 lossyScale = transform.lossyScale;
                Vector3 up = transform.up;
                Vector3 halfRight = transform.right * 0.5f;
                Vector3 halfForward = transform.forward * 0.5f;
                Vector3 top = transform.position + up * lossyScale.y;
                Vector3 bottom = transform.position;

                Vector3[] bottoms = 
                {
                    bottom + halfForward + halfRight,
                    bottom - halfForward + halfRight,
                    bottom - halfForward - halfRight,
                    bottom + halfForward - halfRight
                };

                foreach (var point in bottoms)
                {
                    Gizmos.DrawLine(top, point);
                }

                for (var i  = 0; i < bottoms.Length; ++i)
                {
                    Gizmos.DrawLine(bottoms[i], bottoms[(i + 1) % bottoms.Length]);
                }
            }
        }

        /// <inheritdoc />
        protected override void Initialize()
        {
            base.Initialize();

            clipPyramidHeightID = Shader.PropertyToID("_ClipPyramidHeight");
            clipPyramidInverseTransformID = Shader.PropertyToID("_ClipPyramidInverseTransform");
        }

        protected override void UpdateShaderProperties(MaterialPropertyBlock materialPropertyBlock)
        {
            Vector3 lossyScale = transform.lossyScale;
            materialPropertyBlock.SetFloat(clipPyramidHeightID, lossyScale.y);
            Matrix4x4 pyramidInverseTransform = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one).inverse;
            materialPropertyBlock.SetMatrix(clipPyramidInverseTransformID, pyramidInverseTransform);
        }
    }
}
