//
//  shader.metal
//  originSelectColor
//
//  Created by takasiki on 5/26/1 R.
//  Copyright © 1 Reiwa takasiki. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct {
    float2 position [[ attribute(0) ]];
    float2 texCoord [[ attribute(1) ]];
}Vertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;

vertex ImageColorInOut vertex_main(Vertex in [[ stage_in ]]) {
    ImageColorInOut out;
    
    // Pass through the image vertex's position
    float4 position = float4(in.position,0.0,1.0);
    //position.y += timer;
    out.position = position;
    
    // Pass through the texture coordinate
    out.texCoord = in.texCoord;
    
    return out;
}

// "Fireworks" by Martijn Steinrucken aka BigWings - 2015
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Email:countfrolic@gmail.com Twitter:@The_ArtOfCode

#define PI 3.141592653589793238
#define TWOPI 6.283185307179586
#define S(x,y,z) smoothstep(x,y,z)
#define B(x,y,z,w) S(x-z, x+z, w)*S(y+z, y-z, w)
//#define saturate(x) clamp(x,0.,1.)

// Noise functions by Dave Hoskins
#define MOD3 float3(.1031,.11369,.13787)
#define MOD4 float3(.0031,.10369,.13787)
float3 hash31(float p) {
    float3 p3 = fract(float3(p) * MOD4);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(float3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}
float hash12(float2 p){
    float3 p3  = fract(float3(p.xyx) * MOD4);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float circ(float2 uv, float2 pos, float size) {
    uv -= pos;
    
    size *= size;
    return S(size*1.1, size, dot(uv, uv));
}

float light(float2 uv, float2 pos, float size) {
    uv -= pos;
    
    size *= size;
    return size/dot(uv, uv);
}

float3 origin(float2 uv, float2 p, float2 seed, float t, float3 bCol) {
    
    float3 col = float3(0.);
    
    float3 en = hash12(seed)*0.01;//ノイズ
    float3 baseCol = bCol;// + en;
    for(float i=0.; i<1.0; i++) {
        float3 n = 0.0;
        
        float2 endP = p-float2(0., t*t*.1);//落ちるような表現のためのゴール地点
        
        float pt = 1.0-pow(t-1., 2.);//t-1.0の2乗
        
        float2 pos = p;//mix(p, endP, pt);//落ちるような表現を線形補間を使って実装する
        
        /* 最初の発火の部分を担う
         mixの線形補間ではどのあたりのptの変化値の程よい部分を狙う
         スムーズステップによってptの値をさらに滑らかにしてふわっと光る演出にしている */
        float size = mix(.01, .018, S(0., .1, pt)) * pt;
        //size *= S(1., .1, pt);//後の小さくなっていくアニメーションを担う
        
        col += baseCol*light(uv, pos, size);//ベースカラーをlightという関数で塗るエリアを限定加えてぼやける処理も施す
    }
    
    return col;
}

fragment float4 fragment_main(ImageColorInOut in [[stage_in]],
                              const device float& timer [[ buffer(1) ]],
                              const device float2& pressureZone1    [[ buffer(2) ]],
                              const device float4& slcolor    [[ buffer(3) ]],
                              texture2d<float>  tex2D     [[ texture(0) ]],
                              sampler           sampler2D [[ sampler(0) ]]) {
    
    float2 uv = float2(in.texCoord.x,in.texCoord.y*-1.0); // iResolution.xy;
    uv.x -= 0.5;
    uv.y += 0.5;
    
    float t = timer*0.8;
    float sint = sin(t);
    
    //backbround
    float3 c = float3(0.);
    
    //touch point
    //float2 p = float2(pressureZone1.x,pressureZone1.y);
    float2 ep = float2(0.0,0.0);
    
    for(float i=0.; i<5.0; i++) {
        
        float et = t*0.5;
        float id = floor(et);
        et -= id;
        
        float et2 = t*0.4 - 0.5;
        float id2 = floor(et2);
        et2 -= id2;
        
        float et3 = t*0.3 - 0.25;
        float id3 = floor(et3);
        et3 -= id3;
        
        //ピンク
        float3 bColPin = float3(1.,0.0,0.0);//sin(float3(.5, .3, .3) + float3(1.1244,3.43215,6.435))*float3(.4, .1, .5);
        float3 selectCol = float3(slcolor.x,slcolor.y,slcolor.z);
        
        c = c + origin(uv, ep, id, slcolor.w, selectCol);
        
    }
    
    
    
    return float4(c, 1);
}
