#version 460 core
#include <flutter/runtime_effect.glsl>
precision mediump float;

// 示例1 流动颜色
//out vec4 fragColor;

//uniform vec2 resolution;
//uniform float iTime;
//
//void main(){
//    float strength = 0.25;
//    float t = iTime/8.0;
//    vec3 col = vec3(0);
//    vec2 pos = FlutterFragCoord().xy/resolution.xy;
//    pos = 4.0*(vec2(0.5) - pos);
//    for(float k = 1.0; k < 7.0; k+=1.0){
//        pos.x += strength * sin(2.0*t+k*1.5 * pos.y)+t*0.5;
//        pos.y += strength * cos(2.0*t+k*1.5 * pos.x);
//    }
//    col += 0.5 + 0.5*cos(iTime+pos.xyx+vec3(0,2,4));
//    col = pow(col, vec3(0.4545));
//    fragColor = vec4(col,1.0);
//}

// 示例2 图片

out vec4 fragColor;
uniform vec2 uSize;
uniform sampler2D uTexture;

void main() {
    float rate = uSize.x / uSize.y;
    float cellX = 2.0;
    float cellY = 2.0;
    float rowCount = 100.0;
    vec2 coo = FlutterFragCoord().xy / uSize;

    vec2 sizeFmt = vec2(rowCount, rowCount / rate);
    vec2 sizeMsk = vec2(cellX, cellY / rate);
    vec2 posFmt = vec2(coo.x * sizeFmt.x, coo.y * sizeFmt.y);
    float posMskX = floor(posFmt.x / sizeMsk.x) * sizeMsk.x;
    float posMskY = floor(posFmt.y / sizeMsk.y) * sizeMsk.y;
    vec2 posMsk = vec2(posMskX, posMskY) + 0.5 * sizeMsk;

    bool inCircle = length(posMsk - posFmt)<cellX / 2.0;

    vec4 result;
    if (inCircle) {
        vec2 UVMosaic = vec2(posMsk.x / sizeFmt.x, posMsk.y / sizeFmt.y);
        result = texture(uTexture, UVMosaic);
    } else {
        result = vec4(1.0, 1.0, 1.0, 0.0);
    }
    fragColor = result;
}
