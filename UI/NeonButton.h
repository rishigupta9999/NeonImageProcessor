//
//  NeonButton.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.

#import "Button.h"
#import "Color.h"
#import "PlacementValue.h"

@class BloomGaussianFilter;

typedef enum
{
    NEON_BUTTON_QUALITY_HIGH,
    NEON_BUTTON_QUALITY_MEDIUM,
    NEON_BUTTON_QUALITY_LOW,
    NEON_BUTTON_QUALITY_NUM
} NeonButtonQuality;

typedef struct
{
    NSString*           mTexName;
    NSString*           mBackgroundTexName;
    BOOL                mBloomBackground;
    NeonButtonQuality   mQuality;
    u32                 mFadeSpeed;

    NSString*       mText;
    NSString*       mTextFont;
    u32             mTextSize;
    u32             mBorderSize;
    Color           mTextColor;
    Color           mBorderColor;
    PlacementValue  mTextPlacement;
} NeonButtonParams;

typedef enum
{
    PULSE_STATE_NORMAL,
    PULSE_STATE_POSITIVE,
    PULSE_STATE_HIGHLIGHTED,
    PULSE_STATE_NEGATIVE
} PulseState;

@interface NeonButton : Button
{
    NeonButtonParams        mParams;
    Texture*                mBaseTexture;
    Texture*                mBackgroundTexture;
    Texture*                mTextTexture;
        
    NSMutableArray*         mBlurLayers;
    
    float                   mBlurLevel;
    
    Path*                   mUsePath;
    
    Path*                   mEnabledPath;
    Path*                   mHighlightedPath;
    Path*                   mTransitionPath;
        
    PulseState              mPulseState;
    
    u32                     mTextStartX;
    u32                     mTextStartY;
    u32                     mTextEndX;
    u32                     mTextEndY;
    
    u32                     mFrameDelay;
}

-(NeonButton*)InitWithParams:(NeonButtonParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(NeonButtonParams*)outParams;

-(void)BuildEnabledPath;
-(void)BuildPositiveHighlightedPath;
-(void)BuildNegativeHighlightedPath;

-(void)DrawOrtho;

-(void)StatusChanged:(UIObjectState)inState;

-(BOOL)HitTestWithPoint:(CGPoint*)inPoint;

-(void)CalculateTextPlacement;

-(u32)GetWidth;
-(u32)GetHeight;

@end