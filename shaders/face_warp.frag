#version 460 core
#include <flutter/runtime_effect.glsl>

// 0,1 size (set by the engine for ImageFilter.shader, set by us for still photos)
uniform vec2 uSize;
uniform float uMode;   // 2
uniform float uTime;   // 3
uniform vec4 uFace;    // 4-7   face box x, y, w, h   (0..1 of the picture)
uniform vec4 uEyes;    // 8-11  left eye x,y  right eye x,y
uniform vec4 uMouth;   // 12-15 mouth x, y, width, 0
uniform vec4 uNose;    // 16-19 nose x, y, 0, 0
uniform sampler2D uTexture;

out vec4 fragColor;

// magnify (k > 0) or shrink (k < 0) inside a circle
vec2 bulge(vec2 p, vec2 c, float r, float k) {
  vec2 d = p - c;
  float t = length(d) / r;
  if (t < 1.0) {
    float s = mix(1.0 - k, 1.0, smoothstep(0.0, 1.0, t));
    p = c + d * s;
  }
  return p;
}

// magnify / shrink separately in x and y inside an ellipse
vec2 stretch(vec2 p, vec2 c, vec2 r, vec2 k) {
  vec2 d = (p - c) / r;
  float t = length(d);
  if (t < 1.0) {
    float f = 1.0 - smoothstep(0.0, 1.0, t);
    p = c + (p - c) * (vec2(1.0) - k * f);
  }
  return p;
}

vec2 swirl(vec2 p, vec2 c, float r, float a) {
  vec2 d = p - c;
  float t = length(d) / r;
  if (t < 1.0) {
    float ang = a * (1.0 - t) * (1.0 - t);
    float cs = cos(ang), sn = sin(ang);
    p = c + vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
  }
  return p;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  int mode = int(uMode + 0.5);
  if (mode == 0 || uFace.z <= 0.0) {
    fragColor = texture(uTexture, uv);
    return;
  }
  float aspect = uSize.x / uSize.y;
  vec2 A = vec2(aspect, 1.0);
  vec2 p = uv * A;
  vec2 fc = (uFace.xy + uFace.zw * 0.5) * A;
  float fw = uFace.z * aspect;
  float fh = uFace.w;
  vec2 le = uEyes.xy * A;
  vec2 re = uEyes.zw * A;
  vec2 mo = uMouth.xy * A;
  float mw = max(uMouth.z * aspect, fw * 0.3);
  vec2 no = uNose.xy * A;
  float wob = sin(uTime * 3.0);

  if (mode == 1) {            // BIG MOUTH (opens and closes)
    p = stretch(p, mo, vec2(mw * 1.5, mw * 1.0), vec2(0.55, 0.45 + 0.15 * wob));
  } else if (mode == 2) {     // CRYING BABY: huge sad mouth + big wet eyes
    vec2 d = p - mo;
    float fall = 1.0 - smoothstep(0.0, mw * 1.6, length(d));
    p.y -= (d.x / mw) * (d.x / mw) * mw * 0.45 * fall;   // corners pulled down
    p = stretch(p, mo, vec2(mw * 1.4, mw * 0.9), vec2(0.5, 0.35 + 0.1 * wob));
    p = bulge(p, le, fw * 0.2, 0.35);
    p = bulge(p, re, fw * 0.2, 0.35);
  } else if (mode == 3) {     // BUG EYES
    float k = 0.55 + 0.08 * wob;
    p = bulge(p, le, fw * 0.24, k);
    p = bulge(p, re, fw * 0.24, k);
  } else if (mode == 4) {     // ALIEN: big head, tiny chin
    p = bulge(p, fc - vec2(0.0, fh * 0.3), fw * 0.75, 0.45);
    p = bulge(p, mo + vec2(0.0, fh * 0.12), fw * 0.5, -0.55);
    p = bulge(p, le, fw * 0.2, 0.4);
    p = bulge(p, re, fw * 0.2, 0.4);
  } else if (mode == 5) {     // TINY FACE
    p = bulge(p, fc, max(fw, fh) * 0.85, -0.65);
  } else if (mode == 6) {     // LONG HORSE FACE
    p = stretch(p, fc + vec2(0.0, fh * 0.1), vec2(fw * 0.8, fh * 1.0), vec2(-0.2, 0.35));
  } else if (mode == 7) {     // FAT FACE
    p = stretch(p, fc + vec2(0.0, fh * 0.1), vec2(fw * 0.85, fh * 0.75), vec2(0.4, -0.05));
  } else if (mode == 8) {     // SWIRL
    p = swirl(p, fc, max(fw, fh) * 0.8, 2.6 * wob);
  } else if (mode == 9) {     // DAYYAM: stretched face, black eyes
    p = stretch(p, fc, vec2(fw * 0.8, fh * 1.0), vec2(-0.15, 0.25));
  } else if (mode == 10) {    // BIG NOSE
    p = bulge(p, no, fw * 0.28, 0.6 + 0.05 * wob);
  } else if (mode == 11) {    // CHIPMUNK CHEEKS
    vec2 lc = mix(le, mo, 0.6) + vec2(-fw * 0.12, 0.0);
    vec2 rc = mix(re, mo, 0.6) + vec2(fw * 0.12, 0.0);
    p = bulge(p, lc, fw * 0.26, 0.5);
    p = bulge(p, rc, fw * 0.26, 0.5);
    p = bulge(p, mo, mw * 0.8, -0.3);
  } else if (mode == 12) {    // MIRROR TWIN
    vec2 d = (p - fc) / vec2(fw * 0.75, fh * 0.8);
    if (p.x > fc.x && length(d) < 1.0) p.x = 2.0 * fc.x - p.x;
  } else if (mode == 13) {    // KISSY LIPS
    p = stretch(p, mo, vec2(mw * 1.2, mw * 0.8), vec2(-0.45, 0.35));
  }

  vec2 suv = clamp(p / A, vec2(0.0), vec2(1.0));
  vec4 col = texture(uTexture, suv);

  if (mode == 4) {            // green alien skin
    float inFace = 1.0 - smoothstep(0.7, 1.1, length((uv * A - fc) / vec2(fw * 0.8, fh * 0.85)));
    col.rgb = mix(col.rgb, col.rgb * vec3(0.75, 1.2, 0.7), inFace);
  }
  if (mode == 9) {            // scary: dark, cold, flickering, red-black eyes
    float g = dot(col.rgb, vec3(0.3, 0.59, 0.11));
    float flick = 0.85 + 0.15 * step(0.92, fract(sin(floor(uTime * 12.0)) * 43758.5));
    col.rgb = vec3(g * 0.7, g * 0.85, g * 0.8) * flick;
    float el = length(uv * A - le), er = length(uv * A - re);
    float eye = 1.0 - smoothstep(fw * 0.05, fw * 0.11, min(el, er));
    col.rgb = mix(col.rgb, vec3(0.02, 0.0, 0.0), eye);
    float glow = 1.0 - smoothstep(0.0, fw * 0.05, min(el, er));
    col.rgb += vec3(0.9, 0.05, 0.0) * glow;
    float vig = smoothstep(0.35, 0.95, length(uv - vec2(0.5)));
    col.rgb *= 1.0 - 0.7 * vig;
  }
  fragColor = col;
}
