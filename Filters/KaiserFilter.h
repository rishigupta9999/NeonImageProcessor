//
//  KaiserFilter.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "ConvolutionFilter.h"
#import "NeonMath.h"

@class ImageBuffer;

typedef struct
{
    Texture*        mInputTexture;
    ImageBuffer*    mInputBuffer;
    int             mKernelSize;
    int             mBorder;
    BOOL            mPremultipliedAlpha;
    BOOL            mDynamicOutput;
    Vector2         mOutputSize;
} KaiserFilterParams;

@interface KaiserFilter : ConvolutionFilter
{
}

-(KaiserFilter*)InitWithParams:(KaiserFilterParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(KaiserFilterParams*)outParams;

-(void)GenerateKernel;

@end
