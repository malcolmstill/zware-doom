#version 330 core

out vec4 finalColor;
in vec4 fragColor;
in vec2 fragTexCoord;

uniform sampler2D texture1;

const int colors = 256;
uniform int palette[colors];

vec4 unpackRGBA(int color) {
  vec4 unpackedColor;

  unpackedColor.a = float((color >> 24) & 0xFF) / 255.0;
  unpackedColor.b = float((color >> 16) & 0xFF) / 255.0;
  unpackedColor.g = float((color >> 8) & 0xFF) / 255.0;
  unpackedColor.r = float(color & 0xFF) / 255.0;

  return unpackedColor;
}

void main() {
  vec4 texelColor = texture(texture1, fragTexCoord);

  int index = int(texelColor.r * 255.0);
  vec4 color = unpackRGBA(palette[index]);

  finalColor = vec4(color.xyz, 1.0);
}
