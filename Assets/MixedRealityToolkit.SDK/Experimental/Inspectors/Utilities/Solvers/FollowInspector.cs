using Microsoft.MixedReality.Toolkit.Experimental.Utilities.Solvers;
using Microsoft.MixedReality.Toolkit.Utilities.Editor.Solvers;
using UnityEditor;

namespace Microsoft.MixedReality.Toolkit.Experimental.Utilities.Editor.Solvers
{
    [CustomEditor(typeof(Follow)), CanEditMultipleObjects]
    public class FollowInspector : SolverInspector
    {
        private Follow followSolver = null;

        private static readonly string[] viewDegreeProperties = new string[] { "maxViewHorizontalDegrees", "maxViewVerticalDegrees" };

        protected override void OnEnable()
        {
            base.OnEnable();

            followSolver = target as Follow;
        }

        public override void OnInspectorGUI()
        {
            // When then angular clamp mode is not set to view degrees the view degree properties should not be shown.
            if (followSolver.AngularClampMode == Follow.AngularClampType.ViewDegrees)
            {
                DrawDefaultInspector();
            }
            else
            {
                DrawPropertiesExcluding(serializedObject, viewDegreeProperties);
            }

            serializedObject.ApplyModifiedProperties();
        }
    }
}
