//
//  GaussianBlurFilter.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "GaussianBlurFilter.h"

#import "DynamicTexture.h"
#import "NeonMath.h"

#define DUMP_DEBUG_IMAGES   (0)

@implementation GaussianBlurFilter

-(GaussianBlurFilter*)InitWithParams:(GaussianBlurParams*)inParams
{
    ConvolutionFilterParams convolutionParams;
    
    [ConvolutionFilter InitDefaultParams:&convolutionParams];
    
    convolutionParams.mInputTexture = inParams->mInputTexture;
    convolutionParams.mKernelSize = inParams->mKernelSize;
    convolutionParams.mBorder = inParams->mBorder;
    convolutionParams.mPremultipliedAlpha = inParams->mPremultipliedAlpha;
    convolutionParams.mGenerateOutputTexture = inParams->mGenerateOutputTexture;
    
    [super InitWithParams:&convolutionParams];
    
    return self;
}

-(void)dealloc
{
    [super dealloc];
}

+(void)InitDefaultParams:(GaussianBlurParams*)outParams
{
    outParams->mInputTexture = NULL;
    outParams->mKernelSize = 0;
    outParams->mBorder = 0;
    outParams->mPremultipliedAlpha = FALSE;
    outParams->mGenerateOutputTexture = TRUE;
}

-(void)GenerateKernel
{
    NSAssert((mConvolutionFilterParams.mKernelSize % 2) == 1, @"Even kernel size doesn't work for gaussian blur");

    if (mConvolutionFilterParams.mKernelSize == 0)
    {
        mKernel = NULL;
    }
    else
    {
        mKernel = (float*)malloc(sizeof(float) * mConvolutionFilterParams.mKernelSize);
        
        float* scratch = (float*)malloc(sizeof(float) * mConvolutionFilterParams.mKernelSize);
        
        memset(mKernel, 0, sizeof(float) * mConvolutionFilterParams.mKernelSize);
        memset(scratch, 0, sizeof(float) * mConvolutionFilterParams.mKernelSize);
        
        mKernel[0] = 1.0;
        
        float sum = 0;
        
        for (int curRow = 1; curRow < mConvolutionFilterParams.mKernelSize; curRow++)
        {
            memcpy(scratch, mKernel, sizeof(float) * curRow);
            
            // scratch should now contain the previous row, populate mKernel with the current row
            
            sum = 0;
            
            for (int curCol = 0; curCol <= curRow; curCol++)
            {
                float right = scratch[curCol];
                float left = 0;
                
                if (curCol > 0)
                {
                    left = scratch[curCol - 1];
                }
                
                mKernel[curCol] = right + left;
                
                sum+= mKernel[curCol];
            }
        }
        
        free(scratch);
        
        for (int curCol = 0; curCol < mConvolutionFilterParams.mKernelSize; curCol++)
        {
            mKernel[curCol] /= sum;
        }
    }
}

@end