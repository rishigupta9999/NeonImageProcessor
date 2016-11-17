//
//  BloomGaussianFilter.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "Filter.h"
#import "Color.h"

@class DownsampleFilter;
@class GaussianBlurFilter;
@class DynamicTexture;

typedef struct
{
    Texture*    mInputTexture;
    int         mBorder;
    int         mKernelSize;
    int         mNumDownsampleLevels;
    BOOL        mPremultipliedAlpha;
} BloomGaussianParams;

@interface BloomGaussianFilter : Filter
{
    DownsampleFilter*       mDownsampleFilter;
    GaussianBlurFilter**    mGaussianBlurFilter;
    int                     mNumLevels;
    
    Texture*                mSourceTexture;
    int                     mBorder;
    
    BOOL                    mColorMultiplyEnabled;
    Color                   mColor[4];
    BOOL                    mDrawBaseLayer;
    
    BOOL                    mPremultipliedAlpha;
}

-(BloomGaussianFilter*)InitWithParams:(BloomGaussianParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(BloomGaussianParams*)outParams;

-(void)Update:(CFTimeInterval)inTimeStep;
-(void)Draw;

-(void)SetColorMultiplyEnabled:(BOOL)inEnabled;
-(void)SetColor:(Color)inColorMultiply;
-(void)SetColorPerVertex:(Color*)inColors;

-(void)SetDrawBaseLayer:(BOOL)inDrawBaseLayer;

// If you know that you won't call Update anymore, call this.  You can still access the texture layers,
// but the BloomGaussianFilter will remove its reference to the source texture.
-(void)MarkCompleted;

// If the included draw function isn't advanced enough, this function
// will return texture layers in the order that they should be drawn.
-(NSMutableArray*)GetTextureLayers;
@end
