
#version 460

const float PI = 3.14159265;

// Geometry
const int SEGMENTS = 50;
const int PARTICLE_COUNT = 2;
const int ATOM_COUNT = 3;

const int VERTICES_PER_PARTICLE = SEGMENTS * 3;
const int VERTICES_PER_ATOM =
    PARTICLE_COUNT * VERTICES_PER_PARTICLE;

// Orbital properties
const float ORBITAL_DISTANCE = 0.22;
const float ORBIT_SPEED = 0.5;

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
    float xScale;
    float time;
} viewport;


// Update particle position.
void updateParticle(inout Particle p, vec2 atomPos) {

    if (p.charge == -1) {

        float currentAngle =
            p.angle + viewport.time * ORBIT_SPEED;

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


// Draw an individual particle.
void drawParticle(Particle p, int vertexIdx) {

    vec2 pt = circleTriVertex(p, vertexIdx);

    gl_Position = vec4(
        pt.x * viewport.xScale,
        pt.y,
        0.0,
        1.0
    );

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


// Main vertex shader.
void main() {

    // Which atom does this vertex belong to?
    int atomIndex =
        gl_VertexIndex / VERTICES_PER_ATOM;

    // Safety check.
    if (atomIndex >= ATOM_COUNT) {
        gl_Position = vec4(0.0);
        outColor = vec3(0.0);
        return;
    }

    // Which particle inside that atom?
    int vertexWithinAtom =
        gl_VertexIndex % VERTICES_PER_ATOM;

    int particleIndex =
        vertexWithinAtom / VERTICES_PER_PARTICLE;

    // Which vertex inside that particle?
    int localVertexIndex =
        vertexWithinAtom % VERTICES_PER_PARTICLE;

    // Retrieve the correct atom.
    Atom a = atoms[atomIndex];

    // Retrieve the correct particle.
    Particle p = a.particles[particleIndex];

    // Update particle position.
    updateParticle(p, a.pos);

    // Draw particle.
    drawParticle(p, localVertexIndex);
}
