//
//  ConvolutionFilter.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "ConvolutionFilter.h"

#import "DynamicTexture.h"
#import "NeonMath.h"

#import "ImageBuffer.h"

#define DUMP_DEBUG_IMAGES   (0)

@implementation ConvolutionFilter

-(ConvolutionFilter*)InitWithParams:(ConvolutionFilterParams*)inParams
{
    NSAssert(   (inParams->mWrapMode == WRAP_MODE_ZERO) ||
                ((inParams->mWrapMode == WRAP_MODE_REFLECT) && (inParams->mBorder == 0)),
                @"Unsupported parameter combination");
    
    NSAssert(   (inParams->mInputTexture != NULL) ^ (inParams->mInputBuffer != NULL),
                @"Input texture OR buffer must be provided.  Not both"  );
                
    memcpy(&mConvolutionFilterParams, inParams, sizeof(ConvolutionFilterParams));
    
    mCurrentOutputTextureWidth = 0;
    mCurrentOutputTextureHeight = 0;
    
    mScaleX = 1.0;
    mScaleY = 1.0;
    
    mOutputTexture = NULL;
    mOutputImageBuffer = NULL;
    
    mScratchImageBuffer = NULL;
    
    if (mConvolutionFilterParams.mInputTexture)
    {
        [mConvolutionFilterParams.mInputTexture retain];
        
        ImageBufferParams imageBufferParams;
        [ImageBuffer InitDefaultParams:&imageBufferParams];
        
        imageBufferParams.mWidth = mConvolutionFilterParams.mInputTexture->mGLWidth;
        imageBufferParams.mHeight = mConvolutionFilterParams.mInputTexture->mGLHeight;
        
        imageBufferParams.mEffectiveWidth = mConvolutionFilterParams.mInputTexture->mWidth;
        imageBufferParams.mEffectiveHeight = mConvolutionFilterParams.mInputTexture->mHeight;
        
        if (mConvolutionFilterParams.mInputTexture->mTexBytes == NULL)
        {
            int width = mConvolutionFilterParams.mInputTexture->mGLWidth;
            int height = mConvolutionFilterParams.mInputTexture->mGLHeight;
            
            GLState glState;
            
            SaveGLState(&glState);
            
            GLuint fb;
            
            glGenFramebuffersOES(1, &fb);
            glBindFramebufferOES(GL_FRAMEBUFFER_OES, fb);
            
            glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, mConvolutionFilterParams.mInputTexture->mTexName, 0);
            
            NSAssert(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES, @"Unexpectedly incomplete framebuffer.");
            
            mConvolutionFilterParams.mInputTexture->mTexBytes = malloc(width * height * 4);
            imageBufferParams.mDataOwner = TRUE;
            
            glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, mConvolutionFilterParams.mInputTexture->mTexBytes);
            
            glDeleteFramebuffersOES(1, &fb);
            
            RestoreGLState(&glState);
        }
        else
        {
            imageBufferParams.mDataOwner = FALSE;
        }

        imageBufferParams.mData = (u8*)mConvolutionFilterParams.mInputTexture->mTexBytes;
        
        mInputImageBuffer = [(ImageBuffer*)[ImageBuffer alloc] InitWithParams:&imageBufferParams];
    }
    else if (mConvolutionFilterParams.mInputBuffer)
    {
        [mConvolutionFilterParams.mInputBuffer retain];
        mInputImageBuffer = mConvolutionFilterParams.mInputBuffer;
    }
                    
    if (!inParams->mDynamicOutput)
    {
        [self CreateOutputBuffer:mConvolutionFilterParams.mBorder];
        [self GenerateKernel];
    }
    
    return self;
}

-(void)dealloc
{
    [mConvolutionFilterParams.mInputTexture release];
    [mOutputTexture release];
    [mOutputImageBuffer release];
    [mScratchImageBuffer release];
    [mInputImageBuffer release];
    
    free(mKernel);
    
    [super dealloc];
}

+(void)InitDefaultParams:(ConvolutionFilterParams*)outParams
{
    outParams->mInputTexture = NULL;
    outParams->mInputBuffer = NULL;
    outParams->mKernelSize = 0;
    outParams->mBorder = 0;
    outParams->mPremultipliedAlpha = FALSE;
    outParams->mDynamicOutput = FALSE;
    SetVec2(&outParams->mOutputSize, 0.0, 0.0);
    outParams->mWrapMode = WRAP_MODE_ZERO;
    outParams->mGenerateOutputTexture = FALSE;
}

-(void)Update:(CFTimeInterval)inTimeStep
{    
    if (mConvolutionFilterParams.mInputTexture != NULL)
    {
        int width = mConvolutionFilterParams.mInputTexture->mGLWidth;
        int height = mConvolutionFilterParams.mInputTexture->mGLHeight;
        
        GLState glState;
        
        SaveGLState(&glState);
        
        GLuint fb;
        
        glGenFramebuffersOES(1, &fb);
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, fb);
        
        glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, mConvolutionFilterParams.mInputTexture->mTexName, 0);
        
        NSAssert(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES, @"Unexpectedly incomplete framebuffer.");
        
        mConvolutionFilterParams.mInputTexture->mTexBytes = malloc(width * height * 4);
        glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, mConvolutionFilterParams.mInputTexture->mTexBytes);
        memcpy([mInputImageBuffer GetData], mConvolutionFilterParams.mInputTexture->mTexBytes, width * height * 4);
        
        glDeleteFramebuffersOES(1, &fb);
        
        RestoreGLState(&glState);
        
#if DUMP_DEBUG_IMAGES
        WritePNG(   (u8*)mConvolutionFilterParams.mInputTexture->mTexBytes, @"input.png",
                    mConvolutionFilterParams.mInputTexture->mGLWidth, mConvolutionFilterParams.mInputTexture->mGLHeight);
#endif
    }
#if DUMP_DEBUG_IMAGES
    else if (mConvolutionFilterParams.mInputBuffer != NULL)
    {
        WritePNG(   [mInputImageBuffer GetData], @"input.png", [mInputImageBuffer GetWidth], [mInputImageBuffer GetHeight]);
    }
    
#endif

    // Sanity assertions before we begin processing
    NSAssert( (mScaleX != 0.0) && (mScaleY != 0.0), @"Scale must be non-zero");
    
    ImageBuffer* inputImageBuffer = NULL;
    ImageBuffer* outputImageBuffer = NULL;
    
    for (int pass = 0; pass < 2; pass++)
    {
        if (pass == 0)
        {
            inputImageBuffer = mInputImageBuffer;
            outputImageBuffer = mScratchImageBuffer;
        }
        else
        {
            inputImageBuffer = mScratchImageBuffer;
            outputImageBuffer = mOutputImageBuffer;
        }
        
        [inputImageBuffer SetWrapMode:mConvolutionFilterParams.mWrapMode];
        
        int xMax = [outputImageBuffer GetEffectiveWidth];
        int yMax = [outputImageBuffer GetEffectiveHeight];
                
        for (int y = 0; y < yMax; y++)
        {
            for (int x = 0; x < xMax; x++)
            {
                if ((pass == 0) && (((float)x / mScaleX) >= (float)xMax))
                {
                    break;
                }
                                
                float dstR = 0, dstG = 0, dstB = 0, dstA = 0;
                float srcR = 0, srcG = 0, srcB = 0, srcA = 0;
                float srcANormalized = 0;
                
                for (int k = 0; k < mConvolutionFilterParams.mKernelSize; k++)
                {
                    int sampleX = 0;
                    int sampleY = 0;
                    
                    if (pass == 0)
                    {
                        // The rationale behind this equation is as follows:
                        // (x / mScaleX):   First we modify where we are sampling from depending on the ratio of input vs output
                        //                  If the output is half the size of the input, then mScaleX = 0.5 and x would be doubled.
                        //                  So we're sampling centered on points that are advancing by two.  This make sense
                        //                  since the output buffer is half the width of the input buffer.
                        //
                        // (mConvolutionFilterParams.mKernelSize / 2) + k:  This just shifts the sample based on where in the kernel
                        //                                                  we are.  For example if mKernelSize is 5, we start sampling
                        //                                                  2 pixels to the left of the center, and finish 2 pixels to the right
                        //
                        // Finally, we subtract mBorder because the input texture does not have a border, so we have to offset the sample
                        // into the input texture accordingly.
                        
                        sampleX = (x / mScaleX) - (mConvolutionFilterParams.mKernelSize / 2) + k - mConvolutionFilterParams.mBorder;
                        sampleY = y - mConvolutionFilterParams.mBorder;
                    }
                    else
                    {
                        // The scratch buffer already has the border applied, so no need to offset by mConvolutionFilterParams.mBorder again
                        sampleX = x;
                        sampleY = (y / mScaleY) - (mConvolutionFilterParams.mKernelSize / 2) + k;
                    }
                        
                    u32 val = [inputImageBuffer SampleX:sampleX Y:sampleY];
                    
                    unsigned char* vals = (unsigned char*)&val;
                    
                    srcR = (float)vals[0];
                    srcG = (float)vals[1];
                    srcB = (float)vals[2];
                    srcA = (float)vals[3];
                    
                    srcANormalized = srcA / 255.0;
                    
                    // Premultiply alpha
                    
                    srcR *= srcANormalized;
                    srcG *= srcANormalized;
                    srcB *= srcANormalized;
                    
                    dstR += srcR * mKernel[k];
                    dstG += srcG * mKernel[k];
                    dstB += srcB * mKernel[k];
                    dstA += srcA * mKernel[k];
                }
                
                if (dstA != 0)
                {
                    // Only divide out the alpha if we're not using premultiplied alpha and it's the last pass
                    if (!(mConvolutionFilterParams.mPremultipliedAlpha && (pass == 1)))
                    {
                        dstR /= (dstA / 255.0);
                        dstG /= (dstA / 255.0);
                        dstB /= (dstA / 255.0);
                    }
                    
                    dstR = min(255.0, dstR);
                    dstG = min(255.0, dstG);
                    dstB = min(255.0, dstB);
                }
                                
                u32 outputValue = (((u8)dstA << 24) & 0xFF000000) | (((u8)dstB << 16) & 0x00FF0000) |
                                    (((u8)dstG << 8) & 0x0000FF00) | ((u8)dstR & 0x000000FF);
                                    
                [outputImageBuffer SetSampleX:x Y:y value:outputValue];
            }
        }

#if DUMP_DEBUG_IMAGES        
        if (pass == 0)
        {
            WritePNG([outputImageBuffer GetData], @"scratch.png", [outputImageBuffer GetWidth], [outputImageBuffer GetHeight]);
        }
#endif
    }

#if DUMP_DEBUG_IMAGES
    WritePNG([mOutputImageBuffer GetData], @"output.png", [mOutputImageBuffer GetWidth], [mOutputImageBuffer GetHeight]);
#endif
    
    [mOutputTexture CreateGLTexture];
}

-(ImageBuffer*)GetOutputBuffer
{
    return mOutputImageBuffer;
}

-(Texture*)GetOutputTexture
{
    NSAssert(mConvolutionFilterParams.mGenerateOutputTexture = TRUE, @"mGenerateOutputTexture must be TRUE if you want an output texture");
    return mOutputTexture;
}

-(void)SetOutputSizeX:(u32)inX Y:(u32)inY
{
    NSAssert(mConvolutionFilterParams.mDynamicOutput == TRUE, @"This is only supported for filters with dynamic output sizes.");
    
    mCurrentOutputTextureWidth = inX;
    mCurrentOutputTextureHeight = inY;
    
    [self CreateOutputBuffer:mConvolutionFilterParams.mBorder];
    [self GenerateKernel];
}

-(void)CreateOutputBuffer:(int)inBorder
{
    int outputWidth = 0;
    int outputHeight = 0;
    
    if (mConvolutionFilterParams.mBorder == 0)
    {
        if (    ((mConvolutionFilterParams.mOutputSize.mVector[x] == 0) ||
                (mConvolutionFilterParams.mOutputSize.mVector[y] == 0))
                &&
                ((mCurrentOutputTextureWidth == 0) ||
                (mCurrentOutputTextureHeight == 0)) )
        {
            outputWidth = [mInputImageBuffer GetWidth];
            outputHeight = [mInputImageBuffer GetHeight];
            
            SetVec2(&mConvolutionFilterParams.mOutputSize, outputWidth, outputHeight);
        }
        else
        {
            if ((mCurrentOutputTextureWidth != 0) && (mCurrentOutputTextureHeight != 0))
            {
                outputWidth = mCurrentOutputTextureWidth;
                outputHeight = mCurrentOutputTextureHeight;
            }
            else
            {
                outputWidth = mConvolutionFilterParams.mOutputSize.mVector[x];
                outputHeight = mConvolutionFilterParams.mOutputSize.mVector[y];
            }
        }
    }
    else
    {
        NSAssert(   ((mConvolutionFilterParams.mOutputSize.mVector[x] == 0) && (mConvolutionFilterParams.mOutputSize.mVector[y] == 0)),
                    @"Border unsupported when an explicit output size is provided" );
        
        outputWidth = mConvolutionFilterParams.mInputTexture->mWidth + (mConvolutionFilterParams.mBorder * 2);
        outputHeight = mConvolutionFilterParams.mInputTexture->mHeight + (mConvolutionFilterParams.mBorder * 2);
    }
    
    if (mConvolutionFilterParams.mGenerateOutputTexture)
    {
        TextureCreateParams createParams;
        TextureParams genericParams; 
        
        [DynamicTexture InitDefaultCreateParams:&createParams];
        [Texture InitDefaultParams:&genericParams];
        
        createParams.mWidth = outputWidth;
        createParams.mHeight = outputHeight;
                    
        createParams.mFormat = GL_RGBA;
        createParams.mType = GL_UNSIGNED_BYTE;
        
        mOutputTexture = [[DynamicTexture alloc] InitWithCreateParams:&createParams genericParams:&genericParams];
        
        mOutputTexture->mTexBytes = malloc(mOutputTexture->mGLWidth * mOutputTexture->mGLHeight * 4);
    }
    
    if (mConvolutionFilterParams.mBorder == 0)
    {
        if (!mConvolutionFilterParams.mGenerateOutputTexture)
        {
            mScaleX = (float)outputWidth / (float)[mInputImageBuffer GetEffectiveWidth];
            mScaleY = (float)outputHeight / (float)[mInputImageBuffer GetEffectiveHeight];
        }
        else
        {
            mScaleX = (float)outputWidth / (float)[mInputImageBuffer GetWidth];
            mScaleY = (float)outputHeight / (float)[mInputImageBuffer GetHeight];
        }
    }
    
    if (mOutputImageBuffer != NULL)
    {
        [mOutputImageBuffer release];
    }
    
    ImageBufferParams imageBufferParams;
    [ImageBuffer InitDefaultParams:&imageBufferParams];
    
    imageBufferParams.mDataOwner = FALSE;
        
    if (mOutputTexture == NULL)
    {
        imageBufferParams.mWidth = outputWidth;
        imageBufferParams.mHeight = outputHeight;
        imageBufferParams.mData = (u8*)malloc(outputWidth * outputHeight * 4);
        imageBufferParams.mDataOwner = TRUE;
    }
    else
    {
        imageBufferParams.mEffectiveWidth = outputWidth;
        imageBufferParams.mEffectiveHeight = outputHeight;
        imageBufferParams.mWidth = mOutputTexture->mGLWidth;
        imageBufferParams.mHeight = mOutputTexture->mGLHeight;
        imageBufferParams.mData = (u8*)mOutputTexture->mTexBytes;
    }
    
    
    memset(imageBufferParams.mData, 0, imageBufferParams.mWidth * imageBufferParams.mHeight * 4);
    
    mOutputImageBuffer = [(ImageBuffer*)[ImageBuffer alloc] InitWithParams:&imageBufferParams];
        
    if (mScratchImageBuffer != NULL)
    {
        [mScratchImageBuffer release];
    }
    
    int scratchWidth = 0;
    int scratchHeight = 0;
    
    if (mConvolutionFilterParams.mBorder != 0)
    {
        // Output texture has the border built in.  Assume no resizing to keep the actual convolution logic simpler.
        scratchWidth = [mOutputImageBuffer GetEffectiveWidth];
        scratchHeight = [mOutputImageBuffer GetEffectiveHeight];
    }
    else
    {
        // If there's no border, then we can assume resizing is in place (this logic works equally well with no resizing).
        // We'll use a scratch buffer the same size as the input.
        scratchWidth = [mInputImageBuffer GetWidth];
        scratchHeight = [mInputImageBuffer GetHeight];
    }
    
    [ImageBuffer InitDefaultParams:&imageBufferParams];
    
    imageBufferParams.mWidth = scratchWidth;
    imageBufferParams.mHeight = scratchHeight;
    imageBufferParams.mData = malloc(scratchWidth * scratchHeight * 4);
    imageBufferParams.mDataOwner = TRUE;
    
    memset(imageBufferParams.mData, 0, scratchWidth * scratchHeight * 4);
    
    mScratchImageBuffer = [(ImageBuffer*)[ImageBuffer alloc] InitWithParams:&imageBufferParams];
}

-(void)GenerateKernel
{
}

-(void)NormalizeKernel
{
    float sum = 0;
    
    for (int i = 0; i < mConvolutionFilterParams.mKernelSize; i++)
    {
        sum += mKernel[i];
    }
    
    NSAssert(sum != 0, @"Weights sum to 0.  This cannot be normalized");
    
    for (int i = 0; i < mConvolutionFilterParams.mKernelSize; i++)
    {
        mKernel[i] /= sum;
    }
}

@end