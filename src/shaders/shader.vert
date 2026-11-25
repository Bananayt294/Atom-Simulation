
#version 460

const float PI = 3.14159265;

const int SEGMENTS = 50;
const int PARTICLE_COUNT = 2;
const int VERTICES_PER_PARTICLE = SEGMENTS * 3;

const float ORBITAL_DISTANCE = 0.8;
const float ORBIT_SPEED = 0.5;

struct Particle {
    vec2 pos;
    int charge;
    float angle;
};

Particle particles[PARTICLE_COUNT] = Particle[PARTICLE_COUNT](
    Particle(vec2(0.0, 0.0), 1, 0.0),
    Particle(vec2(-0.8, 0.0), -1, PI)
);

layout(location = 0) out vec3 outColor;

layout(push_constant) uniform Viewport {
    float xScale;
    float time;
} viewport;


// Update particle position.
void updateParticle(inout Particle p) {

    if (p.charge == -1) {

        float currentAngle = p.angle + viewport.time * ORBIT_SPEED;

        p.pos = vec2(
            cos(currentAngle),
            sin(currentAngle)
        ) * ORBITAL_DISTANCE;
    }
}


// Generate a triangle for the particle.
vec2 circleTriVertex(Particle p, int vertexIdx) {

    float radius = (p.charge == -1) ? 0.08 : 0.30;

    int triIdx = vertexIdx / 3;
    int corner = vertexIdx % 3;

    // Center of the particle.
    if (corner == 0) {
        return p.pos;
    }

    // Adjacent perimeter vertices.
    int seg = (corner == 1) ? triIdx : triIdx + 1;

    float angle = 2.0 * PI * float(seg) / float(SEGMENTS);

    return p.pos + vec2(cos(angle), sin(angle)) * radius;
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


void main() {

    // Identify the particle.
    int particleIndex = gl_VertexIndex / VERTICES_PER_PARTICLE;

    // Identify the vertex within that particle.
    int localVertexIndex = gl_VertexIndex % VERTICES_PER_PARTICLE;

    if (particleIndex >= PARTICLE_COUNT) {
        gl_Position = vec4(0.0);
        outColor = vec3(0.0);
        return;
    }

    Particle p = particles[particleIndex];

    updateParticle(p);

    drawParticle(p, localVertexIndex);
}
