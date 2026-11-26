
cmake_minimum_required(VERSION 3.24)

project(VulkanLearning LANGUAGES CXX)

find_package(SDL3 CONFIG REQUIRED)
find_package(Vulkan REQUIRED COMPONENTS volk shaderc_combined)
find_package(glm CONFIG REQUIRED)

add_executable(vulkanapp
    src/main.cpp
    src/application.h
    src/application.cpp
    src/utils.h
    src/utils.cpp
    src/camera.cpp
    src/camera.h)

target_compile_definitions(vulkanapp PRIVATE
    "ATOM_SHADER_DIR=\"${CMAKE_SOURCE_DIR}/src/shaders\""
)

# Enable C++26 working draft features with MSVC.
if(MSVC)
    target_compile_options(vulkanapp PRIVATE /std:c++latest)
else()
    set_target_properties(vulkanapp PROPERTIES
        CXX_STANDARD 26
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )
endif()

target_link_libraries(vulkanapp PRIVATE
    Vulkan::Vulkan
    Vulkan::volk
    Vulkan::shaderc_combined
    SDL3::SDL3
    glm::glm
)

