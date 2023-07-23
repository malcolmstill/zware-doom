#version 330 core
layout(location = 0) in vec3 pos;
layout(location = 1) in vec2 texcoord;

out vec4 fragColor;
out vec2 fragTexCoord;

void main() {
  gl_Position = vec4(pos, 1.0f);
  fragColor = vec4(0.0f, 0.0f, 0.0f, 1.0f);
  fragTexCoord = texcoord;
}
