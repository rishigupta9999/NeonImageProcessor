//
//  Color.c
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.

#include "Color.h"
#include <assert.h>

void SetColor(Color* inColor, u32 inRed, u32 inGreen, u32 inBlue, u32 inAlpha)
{
    inColor->mColorType = COLOR_TYPE_U32;
    
    inColor->mColorData.mDataU32.mRGBAValue =   ((inRed << 24) & 0xFF000000) |
                                                ((inGreen << 16) & 0x00FF0000) |
                                                ((inBlue << 8) & 0x0000FF00) |
                                                (inAlpha & 0x000000FF);
}

void SetColorFloat(Color* inColor, float inRed, float inGreen, float inBlue, float inAlpha)
{
    inColor->mColorType = COLOR_TYPE_FLOAT;
    
    inColor->mColorData.mDataFloat.mRed = inRed;
    inColor->mColorData.mDataFloat.mGreen = inGreen;
    inColor->mColorData.mDataFloat.mBlue = inBlue;
    inColor->mColorData.mDataFloat.mAlpha = inAlpha;
}

void SetColorFromVec4(Color* inColor, Vector4* inVector)
{
    inColor->mColorType = COLOR_TYPE_FLOAT;
    
    inColor->mColorData.mDataFloat.mRed = inVector->mVector[x];
    inColor->mColorData.mDataFloat.mGreen = inVector->mVector[y];
    inColor->mColorData.mDataFloat.mBlue = inVector->mVector[z];
    inColor->mColorData.mDataFloat.mAlpha = inVector->mVector[w];
}

void SetColorFromU32(Color* inColor, u32 inRGBA)
{
    inColor->mColorType = COLOR_TYPE_U32;
    
    inColor->mColorData.mDataU32.mRGBAValue = inRGBA;
}

float GetRedFloat(Color* inColor)
{
    switch(inColor->mColorType)
    {
        case COLOR_TYPE_U32:
        {
            u32 red = (inColor->mColorData.mDataU32.mRGBAValue & 0xFF000000) >> 24;
            
            return ((float)red / 255.0);
        }
        
        case COLOR_TYPE_FLOAT:
        {
            return inColor->mColorData.mDataFloat.mRed;
        }
        
        default:
        {
            assert(!"Unknown color type.");
        }
    }
    
    return 0.0;
}

float GetGreenFloat(Color* inColor)
{
    switch(inColor->mColorType)
    {
        case COLOR_TYPE_U32:
        {
            u32 green = (inColor->mColorData.mDataU32.mRGBAValue & 0x00FF0000) >> 16;
            
            return ((float)green / 255.0);
        }
        
        case COLOR_TYPE_FLOAT:
        {
            return inColor->mColorData.mDataFloat.mGreen;
        }
        
        default:
        {
            assert(!"Unknown color type.");
        }
    }
    
    return 0.0;
}

float GetBlueFloat(Color* inColor)
{
    switch(inColor->mColorType)
    {
        case COLOR_TYPE_U32:
        {
            u32 blue = (inColor->mColorData.mDataU32.mRGBAValue & 0x0000FF00) >> 8;
            
            return ((float)blue / 255.0);
        }
        
        case COLOR_TYPE_FLOAT:
        {
            return inColor->mColorData.mDataFloat.mBlue;
        }
        
        default:
        {
            assert(!"Unknown color type.");
        }
    }
    
    return 0.0;
}

float GetAlphaFloat(Color* inColor)
{
    switch(inColor->mColorType)
    {
        case COLOR_TYPE_U32:
        {
            u32 alpha = inColor->mColorData.mDataU32.mRGBAValue & 0x000000FF;
            
            return ((float)alpha / 255.0);
        }
        
        case COLOR_TYPE_FLOAT:
        {
            return inColor->mColorData.mDataFloat.mAlpha;
        }
        
        default:
        {
            assert(!"Unknown color type.");
        }
    }
    
    return 0.0;
}

u32 GetRGBAU32(Color* inColor)
{    
    switch(inColor->mColorType)
    {
        case COLOR_TYPE_U32:
        {
            return inColor->mColorData.mDataU32.mRGBAValue;
            break;
        }
        
        default:
        {
            assert (!"Unknown color type.");
        }
    }
    
    return 0;
}