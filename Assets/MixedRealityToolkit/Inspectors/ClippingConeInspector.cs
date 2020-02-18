// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.MixedReality.Toolkit.Utilities;
using UnityEditor;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Editor
{
    [CustomEditor(typeof(ClippingCone))]
    public class ClippingConeEditor : UnityEditor.Editor
    {
        private bool HasFrameBounds() { return true; }

        private Bounds OnGetFrameBounds()
        {
            var primitive = target as ClippingCone;
            Debug.Assert(primitive != null);
            return new Bounds(primitive.transform.position, primitive.transform.lossyScale * 0.5f);
        }
    }
}
