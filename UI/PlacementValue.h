//
//  PlacementValue.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.

#pragma once

#include "NeonTypes.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef enum
{
    PLACEMENT_ALIGN_LEFT,
    PLACEMENT_ALIGN_CENTER,
    PLACEMENT_ALIGN_RIGHT,
    PLACEMENT_INVALID
} Placement;

typedef enum
{
    PLACEMENT_TYPE_ABSOLUTE,
    PLACEMENT_TYPE_RELATIVE,
    PLACEMENT_TYPE_INVALID
} PlacementType;

typedef struct
{
    union
    {
        struct
        {
            Placement   mHAlign;
            Placement   mVAlign;
            
            u32         mHAlignPixels;
            u32         mVAlignPixels;
        } mRelativeData;
        
        struct
        {
            u32         mHAlignPixels;
            u32         mVAlignPixels;
            
            u32         mPad1, mPad2;
        } mAbsoluteData;
        
    } mPlacementData;
    
    PlacementType mType;
    
} PlacementValue;

void SetRelativePlacement(PlacementValue* inValue, Placement inHAlign, Placement inVAlign);
void SetAbsolutePlacement(PlacementValue* inValue, u32 inHAlignPixels, u32 inVAlignPixels);
void CalculatePlacement(PlacementValue* inValue, int inOuterWidth, int inOuterHeight, int inInnerWidth, int inInnerHeight);

u32  GetHAlignPixels(PlacementValue* inValue);
u32  GetVAlignPixels(PlacementValue* inValue);

#ifdef __cplusplus
}
#endif /* __cplusplus */