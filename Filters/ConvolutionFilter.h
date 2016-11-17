//
//  ConvolutionFilter.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "Filter.h"
#import "NeonMath.h"
#import "ImageBuffer.h"

@class Texture;
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
    WrapMode        mWrapMode;
    BOOL            mGenerateOutputTexture;
} ConvolutionFilterParams;

@interface ConvolutionFilter : Filter
{
    Texture*        mOutputTexture;
    ImageBuffer*    mOutputImageBuffer;
    
    ImageBuffer*    mScratchImageBuffer;
    
    ImageBuffer*    mInputImageBuffer;
    
    float*          mKernel;
    
    u32             mCurrentOutputTextureWidth;
    u32             mCurrentOutputTextureHeight;
    
    float           mScaleX;
    float           mScaleY;

    ConvolutionFilterParams mConvolutionFilterParams;
}

-(ConvolutionFilter*)InitWithParams:(ConvolutionFilterParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(ConvolutionFilterParams*)outParams;

-(void)Update:(CFTimeInterval)inTimeStep;

-(void)SetOutputSizeX:(u32)inX Y:(u32)inY;
-(void)CreateOutputBuffer:(int)inBorder;
-(Texture*)GetOutputTexture;
-(ImageBuffer*)GetOutputBuffer;

-(void)GenerateKernel;
-(void)NormalizeKernel;

@end