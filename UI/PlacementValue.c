//
//  PlacementValue.c
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.

#include "PlacementValue.h"
#include <stdbool.h>
#include <assert.h>

void SetRelativePlacement(PlacementValue* inValue, Placement inHAlign, Placement inVAlign)
{
    inValue->mType = PLACEMENT_TYPE_RELATIVE;
    
    inValue->mPlacementData.mRelativeData.mHAlign = inHAlign;
    inValue->mPlacementData.mRelativeData.mVAlign = inVAlign;
    
    inValue->mPlacementData.mRelativeData.mHAlignPixels = 0;
    inValue->mPlacementData.mRelativeData.mVAlignPixels = 0;
}

void SetAbsolutePlacement(PlacementValue* inValue, u32 inHAlignPixels, u32 inVAlignPixels)
{
    inValue->mType = PLACEMENT_TYPE_ABSOLUTE;
    
    inValue->mPlacementData.mAbsoluteData.mHAlignPixels = 0;
    inValue->mPlacementData.mAbsoluteData.mVAlignPixels = 0;
}

void CalculatePlacement(PlacementValue* inValue, int inOuterWidth, int inOuterHeight, int inInnerWidth, int inInnerHeight)
{
    switch(inValue->mType)
    {
        // No need to do anything special if absolute placement is specified.  Use the values provided directly.
        case PLACEMENT_TYPE_ABSOLUTE:
        {
            break;
        }
        
        case PLACEMENT_TYPE_RELATIVE:
        {
            switch(inValue->mPlacementData.mRelativeData.mHAlign)
            {
                case PLACEMENT_ALIGN_LEFT:
                {
                    inValue->mPlacementData.mRelativeData.mHAlignPixels = 0;
                    break;
                }
                
                case PLACEMENT_ALIGN_CENTER:
                {
                    inValue->mPlacementData.mRelativeData.mHAlignPixels = (inOuterWidth - inInnerWidth) / 2;
                    break;
                }
                
                case PLACEMENT_ALIGN_RIGHT:
                {
                    inValue->mPlacementData.mRelativeData.mHAlignPixels = inOuterWidth - inInnerWidth;
                    break;
                }
                
                default:
                {
                    assert(false);
                    break;
                }
            }
            
            switch(inValue->mPlacementData.mRelativeData.mVAlign)
            {
                case PLACEMENT_ALIGN_LEFT:
                {
                    inValue->mPlacementData.mRelativeData.mVAlignPixels = 0;
                    break;
                }
                
                case PLACEMENT_ALIGN_CENTER:
                {
                    inValue->mPlacementData.mRelativeData.mVAlignPixels = (inOuterHeight - inInnerHeight) / 2;
                    break;
                }
                
                case PLACEMENT_ALIGN_RIGHT:
                {
                    inValue->mPlacementData.mRelativeData.mVAlignPixels = inOuterHeight - inInnerHeight;
                    break;
                }
                
                default:
                {
                    assert(false);
                    break;
                }
            }
            
            break;
        }
        
        default:
        {
            assert(false);
            break;
        }
    }
}

u32 GetHAlignPixels(PlacementValue* inValue)
{
    u32 retVal = 0;
    
    switch(inValue->mType)
    {
        case PLACEMENT_TYPE_ABSOLUTE:
        {
            retVal = inValue->mPlacementData.mAbsoluteData.mHAlignPixels;
            break;
        }
        
        case PLACEMENT_TYPE_RELATIVE:
        {
            retVal = inValue->mPlacementData.mRelativeData.mHAlignPixels;
            break;
        }
        
        default:
        {
            assert(false);
            break;
        }
    }
    
    return retVal;
}

u32 GetVAlignPixels(PlacementValue* inValue)
{
    u32 retVal = 0;
    
    switch(inValue->mType)
    {
        case PLACEMENT_TYPE_ABSOLUTE:
        {
            retVal = inValue->mPlacementData.mAbsoluteData.mVAlignPixels;
            break;
        }
        
        case PLACEMENT_TYPE_RELATIVE:
        {
            retVal = inValue->mPlacementData.mRelativeData.mVAlignPixels;
            break;
        }
        
        default:
        {
            assert(false);
            break;
        }
    }
    
    return retVal;
}