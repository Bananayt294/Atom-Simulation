
#version 460

const float PI = 3.14159265;

// Geometry
const int SEGMENTS = 50;
const int PARTICLE_COUNT = 2;
const int ATOM_COUNT = 3;

const int VERTICES_PER_PARTICLE = SEGMENTS * 3;

// Orbital properties
const float ORBITAL_DISTANCE = 0.22;
const float ORBIT_SPEED = 0.5;
const float ORBIT_THICKNESS = 0.004;

const int VERTICES_PER_ORBIT = SEGMENTS * 6;

const int PARTICLE_VERTICES_PER_ATOM =
    PARTICLE_COUNT * VERTICES_PER_PARTICLE;

const int VERTICES_PER_ATOM = VERTICES_PER_ORBIT + PARTICLE_VERTICES_PER_ATOM;

// Particle sizes
const float NUCLEUS_RADIUS = 0.11;
const float ELECTRON_RADIUS = 0.035;


// Particle structure.
struct Particle {
    vec2 pos;
    int charge;
    float angle;
};


// Atom structure.
struct Atom {
    vec2 pos;
    Particle particles[PARTICLE_COUNT];
};


// Initialize atoms.
Atom atoms[ATOM_COUNT] = Atom[ATOM_COUNT](

    // Atom 0 - Top left
    Atom(
        vec2(-0.65, 0.45),
        Particle[PARTICLE_COUNT](
            Particle(vec2(0.0), 1, 0.0),
            Particle(vec2(0.0), -1, PI)
        )
    ),

    // Atom 1 - Top right
    Atom(
        vec2(0.65, 0.45),
        Particle[PARTICLE_COUNT](
            Particle(vec2(0.0), 1, 0.0),
            Particle(vec2(0.0), -1, PI)
        )
    ),

    // Atom 2 - Bottom centre
    Atom(
        vec2(0.0, -0.5),
        Particle[PARTICLE_COUNT](
            Particle(vec2(0.0), 1, 0.0),
            Particle(vec2(0.0), -1, PI)
        )
    )
);


layout(location = 0) out vec3 outColor;


// Push constants.
layout(push_constant) uniform Viewport {
    mat4 viewProjection;
    vec4 params;
} viewport;


// Update particle position.
void updateParticle(inout Particle p, vec2 atomPos) {

    if (p.charge == -1) {

        float currentAngle = p.angle + viewport.params.x * ORBIT_SPEED;

        p.pos = atomPos + vec2(
            cos(currentAngle),
            sin(currentAngle)
        ) * ORBITAL_DISTANCE;
    }
    else {
        // Positive particle stays at atom centre.
        p.pos = atomPos;
    }
}


// Generate a triangle for the particle.
vec2 circleTriVertex(Particle p, int vertexIdx) {

    float radius =
        (p.charge == -1) ? ELECTRON_RADIUS : NUCLEUS_RADIUS;

    int triIdx = vertexIdx / 3;
    int corner = vertexIdx % 3;

    // Center of the particle.
    if (corner == 0) {
        return p.pos;
    }

    // Adjacent perimeter vertices.
    int seg = (corner == 1) ? triIdx : triIdx + 1;

    float angle =
        2.0 * PI * float(seg) / float(SEGMENTS);

    return p.pos + vec2(
        cos(angle),
        sin(angle)
    ) * radius;
}


// Generate orbit geometry.
vec2 orbitVertex(vec2 center, int vertexIdx) {

    int segment = vertexIdx / 6;
    int corner = vertexIdx % 6;

    float angle0 =
        2.0 * PI * float(segment) / float(SEGMENTS);

    float angle1 =
        2.0 * PI * float(segment + 1) / float(SEGMENTS);

    float innerRadius =
        ORBITAL_DISTANCE - ORBIT_THICKNESS * 0.5;

    float outerRadius =
        ORBITAL_DISTANCE + ORBIT_THICKNESS * 0.5;

    // Outer perimeter vertices.
    vec2 outer0 = center + vec2(
        cos(angle0),
        sin(angle0)
    ) * outerRadius;

    vec2 outer1 = center + vec2(
        cos(angle1),
        sin(angle1)
    ) * outerRadius;

    // Inner perimeter vertices.
    vec2 inner0 = center + vec2(
        cos(angle0),
        sin(angle0)
    ) * innerRadius;

    vec2 inner1 = center + vec2(
        cos(angle1),
        sin(angle1)
    ) * innerRadius;

    // First triangle: outer0, outer1, inner1
    if (corner == 0 || corner == 3) {
        return outer0;
    }

    if (corner == 1) {
        return outer1;
    }

    if (corner == 2 || corner == 4) {
        return inner1;
    }

    // Second triangle: outer0, inner1, inner0
    return inner0;
}


// Draw an individual particle.
void drawParticle(Particle p, int vertexIdx) {

    vec2 pt = circleTriVertex(p, vertexIdx);

    vec3 worldPosition = vec3(pt, 0.0);

    gl_Position = viewport.viewProjection * vec4(worldPosition, 1.0);

    // Particle color based on charge.
    if (p.charge == -1) {
        outColor = vec3(0.2, 0.6, 1.0);
    }
    else if (p.charge == 1) {
        outColor = vec3(0.0, 1.0, 1.0);
    }
    else {
        outColor = vec3(0.5, 0.5, 0.5);
    }
}


// Draw orbit outline.
void drawOrbit(vec2 atomPos, int vertexIdx) {

    vec2 pt = orbitVertex(atomPos, vertexIdx);

    vec3 worldPosition = vec3(pt, 0.0);

    gl_Position = viewport.viewProjection * vec4(worldPosition, 1.0);

    // Orbit color.
    outColor = vec3(0.15, 0.25, 0.38);
}


// Main vertex shader.
void main() {

    // Identify the atom.
    int atomIndex =
        gl_VertexIndex / VERTICES_PER_ATOM;

    // Safety check.
    if (atomIndex >= ATOM_COUNT) {
        gl_Position = vec4(0.0);
        outColor = vec3(0.0);
        return;
    }

    // Retrieve atom.
    Atom a = atoms[atomIndex];

    // Find vertex within atom.
    int vertexWithinAtom =
        gl_VertexIndex % VERTICES_PER_ATOM;

    // Draw orbit first.
    if (vertexWithinAtom < VERTICES_PER_ORBIT) {

        drawOrbit(a.pos, vertexWithinAtom);
        return;
    }

    // Calculate particle vertex index.
    int particleVertexIndex =
        vertexWithinAtom - VERTICES_PER_ORBIT;

    int particleIndex =
        particleVertexIndex / VERTICES_PER_PARTICLE;

    int localVertexIndex =
        particleVertexIndex % VERTICES_PER_PARTICLE;

    // Safety check for the particle array.
    if (particleIndex >= PARTICLE_COUNT) {
        gl_Position = vec4(0.0);
        outColor = vec3(0.0);
        return;
    }

    // Retrieve particle.
    Particle p = a.particles[particleIndex];

    // Update particle position.
    updateParticle(p, a.pos);

    // Draw particle.
    drawParticle(p, localVertexIndex);
}
