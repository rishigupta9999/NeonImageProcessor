//
//  GaussianBlurFilter.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "ConvolutionFilter.h"

typedef struct
{
    Texture*    mInputTexture;
    int         mKernelSize;
    int         mBorder;
    BOOL        mPremultipliedAlpha;
    BOOL        mGenerateOutputTexture;
} GaussianBlurParams;

@interface GaussianBlurFilter : ConvolutionFilter
{
}

-(GaussianBlurFilter*)InitWithParams:(GaussianBlurParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(GaussianBlurParams*)outParams;

-(void)GenerateKernel;

@end