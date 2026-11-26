
#version 460

layout(location = 0) out vec4 outFragColor;

// Set to 1 to visualize the ray/bounding-sphere intersection.
// Set back to 0 for the actual probability cloud.
const int DEBUG_MODE = 0;

const int MARCH_STEPS = 96;
const float BOUND_RADIUS_IN_SCALES = 6.0;
const float EPSILON = 1e-6;


// ============================================================
// PUSH CONSTANTS
// ============================================================

layout(push_constant) uniform RaymarchData {
    mat4 inverseViewProjection;

    vec4 cameraPosition;

    // x = screen width
    // y = screen height
    // z = orbital radial scale
    // w = density strength
    vec4 params;
} pc;


// ============================================================
// RAY / SPHERE INTERSECTION
// ============================================================

bool intersectSphere(
    vec3 rayOrigin,
    vec3 rayDirection,
    float radius,
    out float tEnter,
    out float tExit
) {
    float b = dot(rayOrigin, rayDirection);
    float c = dot(rayOrigin, rayOrigin) - radius * radius;

    float discriminant = b * b - c;

    if (discriminant < 0.0) {
        tEnter = 0.0;
        tExit = 0.0;
        return false;
    }

    float root = sqrt(discriminant);

    float nearT = -b - root;
    float farT = -b + root;

    // Camera can be inside or outside the volume.
    tEnter = max(nearT, 0.0);
    tExit = farT;

    return tExit > tEnter;
}


// ============================================================
// 2P PROBABILITY DENSITY
// ============================================================

float orbitalDensity(
    vec3 position,
    float radialScale
) {
    float r = length(position);

    if (r < EPSILON) {
        return 0.0;
    }

    // Dimensionless radial coordinate.
    float x = r / radialScale;

    // Polar angle relative to the orbital Y axis.
    float cosTheta = position.y / r;

    // Hydrogen-like 2p spatial probability density.
    float radialDensity = x * x * exp(-x);

    float angularDensity =
        cosTheta * cosTheta;

    return radialDensity * angularDensity;
}


// ============================================================
// DENSITY TO COLOUR
// ============================================================
const float MAX_2P_DENSITY = 0.54134113;

vec3 getCloudColor(float density) {

    // Normalize density into [0, 1].
    float d = clamp(
        density / MAX_2P_DENSITY,
        0.0,
        1.0
    );

    vec3 outerColor = vec3(
        0.004, 0.012, 0.045
    );

    vec3 middleColor = vec3(
        0.008, 0.075, 0.28
    );

    vec3 brightColor = vec3(
        0.025, 0.28, 0.75
    );

    vec3 coreColor = vec3(
        0.12, 0.55, 1.0
    );

    vec3 color = mix(
        outerColor,
        middleColor,
        smoothstep(0.0, 0.25, d)
    );

    color = mix(
        color,
        brightColor,
        smoothstep(0.25, 0.65, d)
    );

    color = mix(
        color,
        coreColor,
        smoothstep(0.65, 1.0, d)
    );

    return color;
}
// ============================================================
// RAY MARCHING
// ============================================================

vec4 rayMarch(
    vec3 rayOrigin,
    vec3 rayDirection
) {
    float radialScale = max(
        pc.params.z,
        0.0001
    );

    float densityStrength = max(
        pc.params.w,
        0.0
    );

    // Bounding sphere containing the orbital.
    float boundRadius =
        radialScale * BOUND_RADIUS_IN_SCALES;

    float tEnter;
    float tExit;

    if (!intersectSphere(
        rayOrigin,
        rayDirection,
        boundRadius,
        tEnter,
        tExit
    )) {
        return vec4(0.0);
    }

    // Distance between ray-marching samples.
    float stepLength = (tExit - tEnter) / float(MARCH_STEPS);

    // Front-to-back accumulation.
    vec3 accumulatedColor = vec3(0.0);

    float accumulatedAlpha = 0.0;

    for (int i = 0; i < MARCH_STEPS; ++i) {

        // Sample at the middle of each interval.
        float t = tEnter +
            (float(i) + 0.5) * stepLength;

        vec3 samplePosition =
            rayOrigin + rayDirection * t;

        // Evaluate probability density.
        float density = orbitalDensity(
            samplePosition,
            radialScale
        );

        // Suppress extremely faint density tails.
        float densityFade = smoothstep(
            0.001,
            0.012,
            density
        );

        density *= densityFade;

        if (density > 0.00001) {

            // Beer-Lambert opacity integration.
            float opticalDepth =
                density *
                densityStrength *
                (stepLength / radialScale);

            float sampleAlpha =
                1.0 - exp(-opticalDepth);

            // Remaining light transmission.
            float transmittance =
                1.0 - accumulatedAlpha;

            // Sample colour.
            vec3 sampleColor =
                getCloudColor(density);

            // Accumulate colour.
            accumulatedColor +=
                transmittance *
                sampleAlpha *
                sampleColor;

            // Accumulate opacity.
            accumulatedAlpha +=
                transmittance *
                sampleAlpha;
        }

        // Early termination.
        if (accumulatedAlpha > 0.995) {
            break;
        }
    }

    return vec4(
        accumulatedColor,
        accumulatedAlpha
    );
}


// ============================================================
// MAIN
// ============================================================

void main() {

    // Screen coordinates -> Normalized Device Coordinates.
    vec2 screenSize = max(
        pc.params.xy,
        vec2(1.0)
    );

    vec2 uv =
        gl_FragCoord.xy / screenSize;

    vec2 ndc =
        uv * 2.0 - 1.0;


    // --------------------------------------------------------
    // RECONSTRUCT WORLD-SPACE CAMERA RAY
    // --------------------------------------------------------

    // Vulkan depth range is [0, 1].
    // Reconstruct near and far points.

    vec4 nearH =
        pc.inverseViewProjection *
        vec4(ndc, 0.0, 1.0);

    vec4 farH =
        pc.inverseViewProjection *
        vec4(ndc, 1.0, 1.0);

    if (
        abs(nearH.w) < EPSILON ||
        abs(farH.w) < EPSILON
    ) {
        outFragColor = vec4(
            0.0015,
            0.003,
            0.009,
            1.0
        );

        return;
    }

    vec3 nearWorld =
        nearH.xyz / nearH.w;

    vec3 farWorld =
        farH.xyz / farH.w;

    vec3 rayOrigin =
        pc.cameraPosition.xyz;

    vec3 rayDirection = normalize(
        farWorld - nearWorld
    );


    // --------------------------------------------------------
    // DEBUG MODE
    // --------------------------------------------------------

    float radialScale = max(
        pc.params.z,
        0.0001
    );

    float boundRadius =
        radialScale * BOUND_RADIUS_IN_SCALES;

    if (DEBUG_MODE == 1) {

        float tEnter;
        float tExit;

        bool hit = intersectSphere(
            rayOrigin,
            rayDirection,
            boundRadius,
            tEnter,
            tExit
        );

        outFragColor = hit
            ? vec4(0.0, 1.0, 0.0, 1.0)
            : vec4(0.0, 0.0, 0.0, 1.0);

        return;
    }


    // --------------------------------------------------------
    // RAY MARCH THE ORBITAL
    // --------------------------------------------------------

    vec4 cloud = rayMarch(
        rayOrigin,
        rayDirection
    );


    // --------------------------------------------------------
    // BACKGROUND COMPOSITING
    // --------------------------------------------------------

    vec3 background = vec3(
        0.0015,
        0.003,
        0.009
    );

    vec3 finalColor =
        background + cloud.rgb;

    outFragColor = vec4(
        finalColor,
        1.0
    );
}
