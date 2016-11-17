//
//  Color.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.

#pragma once

#include "NeonTypes.h"
#include "NeonMath.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef enum
{
    COLOR_TYPE_U32,
    COLOR_TYPE_FLOAT
} ColorType;

typedef struct
{
    union
    {
        struct
        {
            u32 mRGBAValue;
            u32 mPad1, mPad2, mPad3;
        } mDataU32;
        
        struct
        {
            float mRed, mGreen, mBlue, mAlpha;
        } mDataFloat;
        
    } mColorData;
    
    ColorType mColorType;
} Color;

void SetColor(Color* inColor, u32 inRed, u32 inGreen, u32 inBlue, u32 inAlpha);
void SetColorFloat(Color* inColor, float inRed, float inGreen, float inBlue, float inAlpha);
void SetColorFromVec4(Color* inColor, Vector4* inVector);
void SetColorFromU32(Color* inColor, u32 inRGBA);

u32  GetRGBAU32(Color* inColor);

float GetRedFloat(Color* inColor);
float GetGreenFloat(Color* inColor);
float GetBlueFloat(Color* inColor);
float GetAlphaFloat(Color* inColor);

#ifdef __cplusplus
}
#endif /* __cplusplus */