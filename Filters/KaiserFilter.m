//
//  KaiserFilter.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "KaiserFilter.h"

#import "DynamicTexture.h"
#import "NeonMath.h"

#define DUMP_DEBUG_IMAGES   (0)

@implementation KaiserFilter

-(KaiserFilter*)InitWithParams:(KaiserFilterParams*)inParams
{
    ConvolutionFilterParams convolutionParams;
    
    [ConvolutionFilter InitDefaultParams:&convolutionParams];
    
    convolutionParams.mInputTexture = inParams->mInputTexture;
    convolutionParams.mInputBuffer = inParams->mInputBuffer;
    convolutionParams.mKernelSize = inParams->mKernelSize;
    convolutionParams.mBorder = inParams->mBorder;
    convolutionParams.mPremultipliedAlpha = inParams->mPremultipliedAlpha;
    convolutionParams.mDynamicOutput = inParams->mDynamicOutput;
    CloneVec2(&inParams->mOutputSize, &mConvolutionFilterParams.mOutputSize);
    convolutionParams.mWrapMode = WRAP_MODE_REFLECT;
        
    [super InitWithParams:&convolutionParams];
            
    return self;
}

-(void)dealloc
{
    [super dealloc];
}

+(void)InitDefaultParams:(KaiserFilterParams*)outParams
{
    outParams->mInputTexture = NULL;
    outParams->mInputBuffer = NULL;
    outParams->mKernelSize = 0;
    outParams->mBorder = 0;
    outParams->mPremultipliedAlpha = FALSE;
    outParams->mDynamicOutput = FALSE;
    SetVec2(&outParams->mOutputSize, 0.0, 0.0);
}

-(void)GenerateKernel
{
    if (mKernel != NULL)
    {
        free(mKernel);
        mKernel = NULL;
    }
    
    if (mConvolutionFilterParams.mKernelSize == 0)
    {
        mKernel = NULL;
    }
    else
    {
        int width = mConvolutionFilterParams.mKernelSize;
        NSAssert( (width % 2) == 0, @"Kernel width must be even");

        mKernel = (float*)malloc(sizeof(float) * width);
        
        int alpha = 4.0;
        
        //NSAssert(mScaleX == mScaleY, @"Height and width scale factors must be equal");
    
        float halfWidth = (float)(width / 2);
        float offset = -halfWidth;
        float nudge = 0.5f;

        for (int i = 0; i < width; i++)
        {
            float x = (i + offset) + nudge;

            double sincValue = Sinc(x * mScaleX);
            double windowValue = Kaiser(alpha, halfWidth, x * mScaleX);

            mKernel[i] = sincValue * windowValue;
        }
        
        [self NormalizeKernel];
    }
}

@end