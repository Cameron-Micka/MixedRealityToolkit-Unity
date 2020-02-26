// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities;
using UnityEditor;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Editor
{
    [CustomEditor(typeof(ClippingFrustum))]
    public class ClippingFrustumEditor : UnityEditor.Editor
    {
        private bool HasFrameBounds() { return true; }

        private Bounds OnGetFrameBounds()
        {
            var primitive = target as ClippingFrustum;
            Debug.Assert(primitive != null);
            return new Bounds(primitive.transform.position, Vector3.one * (primitive.Far * 0.5f));
        }
    }
}
