#pragma once

#include <glm/glm.hpp>

class Camera {
public:
    glm::mat4 getViewMatrix() const;
    glm::mat4 getProjectionMatrix(float aspectRatio) const;

    void setPosition(const glm::vec3& newPosition);

    void moveForward(float amount);
    void moveRight(float amount);
    void moveUp(float amount);

    void rotate(float deltaX, float deltaY);

private:
    glm::vec3 position{ 0.0f, 0.0f, 3.0f };

    float yaw = -90.0f;
    float pitch = 0.0f;

    float fov = 45.0f;
    float nearPlane = 0.1f;
    float farPlane = 100.0f;

    glm::vec3 getForwardDirection() const;
};