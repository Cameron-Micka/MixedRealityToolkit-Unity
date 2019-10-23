// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

using Microsoft.MixedReality.Toolkit.Utilities;
using Microsoft.MixedReality.Toolkit.Utilities.Solvers;
using UnityEngine;

namespace Microsoft.MixedReality.Toolkit.Experimental.Utilities.Solvers
{
    /// <summary>
    /// Follow solver positions an element relative in front of the forward axis of the tracked target.
    /// The element can be loosely constrained (a.k.a. tag-along) so that it doesn't follow until it is too far.
    /// </summary>
    public class Follow : Solver
    {
        [Experimental]
        [SerializeField]
        [Tooltip("The desired orientation of this object")]
        private SolverOrientationType orientationType = SolverOrientationType.Unmodified;

        /// <summary>
        /// The desired orientation of this object.
        /// </summary>
        public SolverOrientationType OrientationType
        {
            get { return orientationType; }
            set { orientationType = value; }
        }

        [SerializeField]
        [Tooltip("Min distance from tracked target to position element around, i.e. the sphere radius")]
        private float minDistance = 1f;

        /// <summary>
        /// Min distance from tracked target to position element around, i.e. the sphere radius.
        /// </summary>
        public float MinDistance
        {
            get { return minDistance; }
            set { minDistance = value; }
        }

        [SerializeField]
        [Tooltip("Max distance from tracked target to element")]
        private float maxDistance = 2f;

        /// <summary>
        /// Max distance from tracked target to element.
        /// </summary>
        public float MaxDistance
        {
            get { return maxDistance; }
            set { maxDistance = value; }
        }

        [SerializeField]
        [Tooltip("Min distance from tracked target to position element around, i.e. the sphere radius")]
        private float defaultDistance = 1f;

        /// <summary>
        /// Initial placement distance. Should be between min and max.
        /// </summary>
        public float DefaultDistance
        {
            get { return defaultDistance; }
            set { defaultDistance = value; }
        }

        /// <summary>
        /// TODO
        /// </summary>
        public enum AngularClampType
        {
            ViewDegrees = 0,
            RendererBounds = 1,
            ColliderBounds = 2,
        }

        [SerializeField]
        [Tooltip("TODO")]
        private AngularClampType angularClampMode = AngularClampType.RendererBounds;

        /// <summary>
        /// TODO
        /// </summary>
        public AngularClampType AngularClampMode
        {
            get { return angularClampMode; }
            set { angularClampMode = value; }
        }

        [SerializeField]
        [Tooltip("The element will stay at least this close to the center of view")]
        private float maxViewHorizontalDegrees = 30f;

        /// <summary>
        /// The element will stay at least this close to the center of view.
        /// </summary>
        public float MaxViewHorizontalDegrees
        {
            get { return maxViewHorizontalDegrees; }
            set { maxViewHorizontalDegrees = value; }
        }

        [SerializeField]
        [Tooltip("The element will stay at least this close to the center of view")]
        private float maxViewVerticalDegrees = 30f;

        /// <summary>
        /// The element will stay at least this close to the center of view.
        /// </summary>
        public float MaxViewVerticalDegrees
        {
            get { return maxViewVerticalDegrees; }
            set { maxViewVerticalDegrees = value; }
        }

        [SerializeField]
        [Tooltip("TODO")]
        private float boundMargin = 1.0f;

        /// <summary>
        /// TODO
        /// </summary>
        public float BoundMargin
        {
            get { return boundMargin; }
            set { boundMargin = value; }
        }

        [SerializeField]
        [Tooltip("The element will stay world lock until the angle between the forward vector and vector to the controller is greater then the deadzone")]
        private float orientToControllerDeadzoneDegrees = 60f;

        /// <summary>
        /// The element will stay world lock until the angle between the forward vector and vector to the controller is greater then the deadzone.
        /// </summary>
        public float OrientToControllerDeadzoneDegrees
        {
            get { return orientToControllerDeadzoneDegrees; }
            set { orientToControllerDeadzoneDegrees = value; }
        }

        [SerializeField]
        [Tooltip("Option to ignore angle clamping")]
        private bool ignoreAngleClamp = false;

        /// <summary>
        /// Option to ignore angle clamping.
        /// </summary>
        public bool IgnoreAngleClamp
        {
            get { return ignoreAngleClamp; }
            set { ignoreAngleClamp = value; }
        }

        [SerializeField]
        [Tooltip("Option to ignore distance clamping")]
        private bool ignoreDistanceClamp = false;

        /// <summary>
        /// Option to ignore distance clamping.
        /// </summary>
        public bool IgnoreDistanceClamp
        {
            get { return ignoreDistanceClamp; }
            set { ignoreDistanceClamp = value; }
        }

        [SerializeField]
        [Tooltip("Option to ignore the pitch and roll of the reference target")]
        private bool ignoreReferencePitchAndRoll = false;

        /// <summary>
        /// Option to ignore the pitch and roll of the reference target
        /// </summary>
        public bool IgnoreReferencePitchAndRoll
        {
            get { return ignoreReferencePitchAndRoll; }
            set { ignoreReferencePitchAndRoll = value; }
        }

        [SerializeField]
        [Tooltip("Pitch offset from reference element (relative to Max Distance)")]
        public float pitchOffset = 0;

        /// <summary>
        /// Pitch offset from reference element (relative to MaxDistance).
        /// </summary>
        /// [SerializeField]
        public float PitchOffset
        {
            get { return pitchOffset; }
            set { pitchOffset = value; }
        }

        [SerializeField]
        [Tooltip("Max vertical distance between element and reference")]
        private float verticalMaxDistance = 0.0f;

        /// <summary>
        /// Max vertical distance between element and reference.
        /// </summary>
        public float VerticalMaxDistance
        {
            get { return verticalMaxDistance; }
            set { verticalMaxDistance = value; }
        }

        [SerializeField]
        [Tooltip("Enables/disables debug drawing of solver elements (such as angular clamping properties).")]
        private bool debugDraw = false;

        /// <summary>
        /// Enables/disables debug drawing of solver elements (such as angular clamping properties).
        /// </summary>
        public bool DebugDraw
        {
            get { return debugDraw; }
            set { debugDraw = value; }
        }

        public void Recenter()
        {
            recenterNextUpdate = true;
        }

        private Vector3 ReferencePosition => SolverHandler.TransformTarget != null ? SolverHandler.TransformTarget.position : Vector3.zero;
        private Quaternion ReferenceRotation => SolverHandler.TransformTarget != null ? SolverHandler.TransformTarget.rotation : Quaternion.identity;
        private Vector3 PreviousReferencePosition = Vector3.zero;
        private Quaternion PreviousReferenceRotation = Quaternion.identity;
        private bool recenterNextUpdate = true;

        protected override void OnEnable()
        {
            base.OnEnable();
            Recenter();
        }

        /// <inheritdoc />
        public override void SolverUpdate()
        {
            Vector3 refPosition = Vector3.zero;
            Quaternion refRotation = Quaternion.identity;
            GetReferenceInfo(
                PreviousReferencePosition,
                ReferencePosition,
                ReferenceRotation,
                VerticalMaxDistance,
                ref refPosition,
                ref refRotation);

            // Determine the current position of the element
            Vector3 currentPosition = WorkingPosition;
            if (recenterNextUpdate)
            {
                currentPosition = refPosition + (refRotation * Vector3.forward) * DefaultDistance;
            }

            Bounds bounds;
            GetBounds(gameObject, angularClampMode, out bounds);

            // Angularly clamp to determine goal direction to place the element
            Vector3 goalDirection = refRotation * Vector3.forward;
            SolverOrientationType orientation = orientationType;
            bool angularClamped = false;
            if (!ignoreAngleClamp && !recenterNextUpdate)
            {
                angularClamped = AngularClamp(
                    refPosition,
                    PreviousReferencePosition,
                    refRotation,
                    PreviousReferenceRotation,
                    currentPosition,
                    IgnoreReferencePitchAndRoll,
                    MaxViewHorizontalDegrees,
                    MaxViewVerticalDegrees,
                    bounds,
                    ref goalDirection);

                if (angularClamped)
                {       
                    orientation = SolverOrientationType.FaceTrackedObject;
                }
            }

            // Distance clamp to determine goal position to place the element
            Vector3 goalPosition = currentPosition;
            bool distanceClamped = false;
            if (!ignoreDistanceClamp)
            {
                distanceClamped = DistanceClamp(
                    MinDistance,
                    DefaultDistance,
                    MaxDistance,
                    (PitchOffset != 0),
                    currentPosition,
                    refPosition,
                    goalDirection,
                    ref goalPosition);

                if (distanceClamped)
                {       
                    orientation = SolverOrientationType.FaceTrackedObject;
                }
            }

            // Figure out goal rotation of the element based on orientation setting
            Quaternion goalRotation = Quaternion.identity;
            ComputeOrientation(
                orientation,
                orientToControllerDeadzoneDegrees,
                goalPosition,
                ref goalRotation);

            PreviousReferencePosition = refPosition;
            PreviousReferenceRotation = refRotation;
            recenterNextUpdate = false;

            // Avoid drift by not updating the goal when not clamped.
            if (distanceClamped)
            {
                GoalPosition = goalPosition;
            }

            GoalRotation = goalRotation;
        }

        float AngleBetweenOnXZPlane(Vector3 from, Vector3 to)
        {
            float angle = Mathf.Atan2(to.z, to.x) - Mathf.Atan2(from.z, from.x);
            return SimplifyAngle(angle) * Mathf.Rad2Deg;
        }

        float AngleBetweenOnXYPlane(Vector3 from, Vector3 to)
        {
            float angle = Mathf.Atan2(to.y, to.x) - Mathf.Atan2(from.y, from.x);
            return SimplifyAngle(angle) * Mathf.Rad2Deg;
        }

        float AngleBetweenOnAxis(Vector3 from, Vector3 to, Vector3 axis)
        {
            Quaternion axisQuat = Quaternion.Inverse(Quaternion.LookRotation(axis));
            Vector3 v1 = axisQuat * from;
            Vector3 v2 = axisQuat * to;
            return AngleBetweenOnXYPlane(v1, v2);
        }

        float SimplifyAngle(float angle)
        {
            while (angle > Mathf.PI)
            {
                angle -= 2 * Mathf.PI;
            }

            while (angle < -Mathf.PI)
            {
                angle += 2 * Mathf.PI;
            }

            return angle;
        }

        private bool AngularClamp(
            Vector3 refPosition,
            Vector3 previousRefPosition,
            Quaternion refRotation,
            Quaternion previousRefRotation,
            Vector3 currentPosition,
            bool ignoreVertical,
            float maxHorizontalDegrees,
            float maxVerticalDegrees,
            Bounds bounds,
            ref Vector3 refForward)
        {
            Vector3 toTarget = currentPosition - refPosition;
            float currentDistance = toTarget.magnitude;
            if (currentDistance <= 0)
            {
                // No need to clamp
                return false;
            }

            toTarget.Normalize();

            // Start off with a rotation towards the target. If it's within leashing bounds, we can leave it alone.
            Quaternion rotation = Quaternion.LookRotation(toTarget, Vector3.up);

            // This is the meat of the leashing algorithm. The goal is to ensure that the reference's forward
            // vector remains within the bounds set by the leashing parameters. To do this, determine the angles
            // between toTarget and the leashing bounds about the global Y axis and the reference's X axis.
            // If toTarget falls within the leashing bounds, then we don't have to modify it.
            // Otherwise, we apply a correction rotation to bring it within bounds.

            Vector3 currentRefForward = refRotation * Vector3.forward;
            Vector3 refRight = refRotation * Vector3.right;

            bool angularClamped = false;

            Vector3 extents = bounds.extents * boundMargin;

            // X-axis leashing
            // Leashing around the reference's X axis only makes sense if the reference isn't gravity aligned.
            if (ignoreVertical)
            {
                float angle = AngleBetweenOnAxis(toTarget, currentRefForward, refRight);
                rotation = Quaternion.AngleAxis(angle, refRight) * rotation;
            }
            else
            {
                Vector3 min;
                Vector3 max;

                switch (angularClampMode)
                {
                    default:
                    case AngularClampType.ViewDegrees:
                        {
                            min = Quaternion.AngleAxis(maxVerticalDegrees * 0.5f, refRight) * refForward;
                            max = Quaternion.AngleAxis(-maxVerticalDegrees * 0.5f, refRight) * refForward;
                        }
                        break;

                    case AngularClampType.RendererBounds:
                    case AngularClampType.ColliderBounds:
                        {
                            min = refRotation * new Vector3(0.0f, -extents.y, currentDistance);
                            max = refRotation * new Vector3(0.0f, extents.y, currentDistance);
                        }
                        break;
                }

                if (debugDraw)
                {
                    Debug.DrawLine(refPosition, refPosition + min, Color.blue);
                    Debug.DrawLine(refPosition, refPosition + max, Color.blue);
                }

                float minAngle = AngleBetweenOnAxis(toTarget, min, refRight);
                float maxAngle = AngleBetweenOnAxis(toTarget, max, refRight);

                if (minAngle < 0)
                {
                    rotation = Quaternion.AngleAxis(minAngle, refRight) * rotation;
                    angularClamped = true;
                }
                else if (maxAngle > 0)
                {
                    rotation = Quaternion.AngleAxis(maxAngle, refRight) * rotation;
                    angularClamped = true;
                }
            }

            // Y-axis leashing
            {
                Vector3 min;
                Vector3 max;

                switch (angularClampMode)
                {
                    default:
                    case AngularClampType.ViewDegrees:
                        {
                            min = Quaternion.AngleAxis(-maxHorizontalDegrees * 0.5f, Vector3.up) * refForward;
                            max = Quaternion.AngleAxis(maxHorizontalDegrees * 0.5f, Vector3.up) * refForward;
                        }
                        break;

                    case AngularClampType.RendererBounds:
                    case AngularClampType.ColliderBounds:
                        {
                            var extentsXZ = new Vector3(extents.x, 0.0f, extents.z);
                            var extentsXZMagnitude = extentsXZ.magnitude;
                            min = refRotation * new Vector3(-extentsXZMagnitude, 0.0f, currentDistance);
                            max = refRotation * new Vector3(extentsXZMagnitude, 0.0f, currentDistance);

                            if (debugDraw)
                            {
                                bounds.DebugDraw(Color.red);
                            }
                        }
                        break;
                }

                if (debugDraw)
                {
                    Debug.DrawLine(refPosition, refPosition + toTarget, Color.yellow);
                    Debug.DrawLine(refPosition, refPosition + min, Color.green);
                    Debug.DrawLine(refPosition, refPosition + max, Color.green);
                }

                // These are negated because Unity is left-handed
                float minAngle = -AngleBetweenOnXZPlane(toTarget, min);
                float maxAngle = -AngleBetweenOnXZPlane(toTarget, max);

                if (minAngle > 0)
                {
                    rotation = Quaternion.AngleAxis(minAngle, Vector3.up) * rotation;
                    angularClamped = true;
                }
                else if (maxAngle < 0)
                {
                    rotation = Quaternion.AngleAxis(maxAngle, Vector3.up) * rotation;
                    angularClamped = true;
                }
            }

            refForward = rotation * Vector3.forward;

            // When moving quickly the solver can fall behind the tracked object and face the wrong direction to avoid
            // that case the forward is negated to keep the object billboarded correctly.
            if (Vector3.Dot(refForward, previousRefRotation * Vector3.forward) < 0)
            {
                refForward *= -1.0f;
            }

            return angularClamped;
        }

        bool DistanceClamp(
            float minDistance,
            float defaultDistance,
            float maxDistance,
            bool maintainPitch,
            Vector3 currentPosition,
            Vector3 refPosition,
            Vector3 refForward,
            ref Vector3 clampedPosition)
        {
            float clampedDistance;
            float currentDistance = Vector3.Distance(currentPosition, refPosition);
            Vector3 direction = refForward;
            if (maintainPitch)
            {
                // If we don't account for pitch offset, the casted object will float up/down as the reference
                // gets closer to it because we will still be casting in the direction of the pitched offset.
                // To fix this, only modify the XZ position of the object.

                Vector3 directionXZ = refForward;
                directionXZ.y = 0;
                directionXZ.Normalize();

                Vector3 refToElementXZ = currentPosition - refPosition;
                refToElementXZ.y = 0;
                float desiredDistanceXZ = refToElementXZ.magnitude;

                Vector3 minDistanceXZVector = refForward * minDistance;
                minDistanceXZVector.y = 0;
                float minDistanceXZ = minDistanceXZVector.magnitude;

                Vector3 maxDistanceXZVector = refForward * maxDistance;
                maxDistanceXZVector.y = 0;
                float maxDistanceXZ = maxDistanceXZVector.magnitude;

                desiredDistanceXZ = Mathf.Clamp(desiredDistanceXZ, minDistanceXZ, maxDistanceXZ);

                Vector3 desiredPosition = refPosition + directionXZ * desiredDistanceXZ;
                float desiredHeight = refPosition.y + refForward.y * maxDistance;
                desiredPosition.y = desiredHeight;

                direction = desiredPosition - refPosition;
                clampedDistance = direction.magnitude;
                direction /= clampedDistance;

                clampedDistance = Mathf.Max(minDistance, clampedDistance);
            }
            else
            {
                clampedDistance = Mathf.Clamp(currentDistance, minDistance, maxDistance);
            }

            clampedPosition = refPosition + direction * clampedDistance;

            return Vector3EqualEpsilon(clampedPosition, currentPosition, 0.0001f);
        }

        void ComputeOrientation(
            SolverOrientationType defaultOrientationType,
            float orientToControllerDeadzoneRadians,
            Vector3 goalPosition,
            ref Quaternion orientation)
        {
            Vector3 nodeToCamera = goalPosition - ReferencePosition;
            float angle = Mathf.Abs(AngleBetweenOnXZPlane(transform.forward, nodeToCamera));
            if (angle > orientToControllerDeadzoneRadians)
            {
                defaultOrientationType = SolverOrientationType.FaceTrackedObject;
            }

            switch (defaultOrientationType)
            {
                case SolverOrientationType.YawOnly:
                    float targetYRotation = SolverHandler.TransformTarget != null ? SolverHandler.TransformTarget.eulerAngles.y : 0.0f;
                    orientation = Quaternion.Euler(0f, targetYRotation, 0f);
                    break;
                case SolverOrientationType.Unmodified:
                    orientation = GoalRotation;
                    break;
                case SolverOrientationType.CameraAligned:
                    orientation = CameraCache.Main.transform.rotation;
                    break;
                case SolverOrientationType.FaceTrackedObject:
                    orientation = SolverHandler.TransformTarget != null ? Quaternion.LookRotation(goalPosition - ReferencePosition) : Quaternion.identity;
                    break;
                case SolverOrientationType.CameraFacing:
                    orientation = SolverHandler.TransformTarget != null ? Quaternion.LookRotation(goalPosition - CameraCache.Main.transform.position) : Quaternion.identity;
                    break;
                case SolverOrientationType.FollowTrackedObject:
                    orientation = SolverHandler.TransformTarget != null ? ReferenceRotation : Quaternion.identity;
                    break;
                default:
                    Debug.LogError($"Invalid OrientationType for Orbital Solver on {gameObject.name}");
                    break;
            }
        }

        void GetReferenceInfo(
            Vector3 previousRefPosition,
            Vector3 currentRefPosition,
            Quaternion currentRefRotation,
            float verticalMaxDistance,
            ref Vector3 refPosition,
            ref Quaternion refRotation)
        {
            refPosition = currentRefPosition;
            refRotation = currentRefRotation;
            if (IgnoreReferencePitchAndRoll)
            {
                Vector3 forward = currentRefRotation * Vector3.forward;
                forward.y = 0;
                refRotation = Quaternion.LookRotation(forward);
                if (PitchOffset != 0)
                {
                    Vector3 right = refRotation * Vector3.right;
                    forward = Quaternion.AngleAxis(PitchOffset, right) * forward;
                    refRotation = Quaternion.LookRotation(forward);
                }
            }

            // Apply vertical clamp on reference
            if (!recenterNextUpdate && verticalMaxDistance > 0)
            {
                refPosition.y = Mathf.Clamp(previousRefPosition.y, currentRefPosition.y - verticalMaxDistance, currentRefPosition.y + verticalMaxDistance);
            }
        }

        bool Vector3EqualEpsilon(Vector3 x, Vector3 y, float eps)
        {
            float sqrMagnitude = (x - y).sqrMagnitude;

            return sqrMagnitude > eps;
        }

        private static bool GetBounds(GameObject target, AngularClampType angularClampType, out Bounds bounds)
        {
            switch (angularClampType)
            {
                case AngularClampType.RendererBounds:
                    {
                        return BoundsExtensions.GetRenderBounds(target, out bounds, 0);
                    }

                case AngularClampType.ColliderBounds:
                    {
                        return BoundsExtensions.GetColliderBounds(target, out bounds, 0);
                    }
            }

            bounds = new Bounds();
            return false;
        }
    }
}