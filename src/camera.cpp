#include "camera.h"

#include <glm/gtc/matrix_transform.hpp>

#include <algorithm>
#include <cmath>

glm::mat4 Camera::getViewMatrix() const {
    return glm::lookAtRH(
        position,
        position + getForwardDirection(),
        glm::vec3(0.0f, 1.0f, 0.0f)
    );
}

glm::mat4 Camera::getProjectionMatrix(float aspectRatio) const {
    glm::mat4 projection = glm::perspectiveRH_ZO(
        glm::radians(fov),
        aspectRatio,
        nearPlane,
        farPlane
    );

    // Vulkan coordinate convention.
    projection[1][1] *= -1.0f;

    return projection;
}

glm::vec3 Camera::getForwardDirection() const {
    glm::vec3 direction;

    direction.x = std::cos(glm::radians(yaw)) *
        std::cos(glm::radians(pitch));

    direction.y = std::sin(glm::radians(pitch));

    direction.z = std::sin(glm::radians(yaw)) *
        std::cos(glm::radians(pitch));

    return glm::normalize(direction);
}

void Camera::setPosition(const glm::vec3& newPosition) {
    position = newPosition;
}

void Camera::moveForward(float amount) {
    position += getForwardDirection() * amount;
}

void Camera::moveRight(float amount) {
    glm::vec3 right = glm::normalize(
        glm::cross(
            getForwardDirection(),
            glm::vec3(0.0f, 1.0f, 0.0f)
        )
    );

    position += right * amount;
}

void Camera::moveUp(float amount) {
    position.y += amount;
}

void Camera::rotate(float deltaX, float deltaY) {
    yaw += deltaX;
    pitch = std::clamp(pitch + deltaY, -89.0f, 89.0f);
}