//
//  BloomGaussianFilter.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "BloomGaussianFilter.h"
#import "DownsampleFilter.h"
#import "GaussianBlurFilter.h"

#import "Texture.h"
#import "DynamicTexture.h"

#define DEFAULT_NUM_DOWNSAMPLE_LEVELS (4)
#define GAUSSIAN_BLUR_KERNEL_SIZE (5)

@implementation BloomGaussianFilter

-(BloomGaussianFilter*)InitWithParams:(BloomGaussianParams*)inParams
{
    if (inParams->mNumDownsampleLevels > 0)
    {
        mDownsampleFilter = (DownsampleFilter*)[(DownsampleFilter*)[DownsampleFilter alloc] InitWithTexture:inParams->mInputTexture numLevels:(inParams->mNumDownsampleLevels - 1)];
        
        // We're applying gaussian on the base level too - that requires no downsampling.
        mNumLevels = [mDownsampleFilter GetNumLevels] + 1;
    }
    else
    {
        mDownsampleFilter = NULL;
        mNumLevels = 1;
    }
    
    mPremultipliedAlpha = inParams->mPremultipliedAlpha;
    
    mGaussianBlurFilter = malloc(sizeof(GaussianBlurFilter*) * mNumLevels);
    
    GaussianBlurParams gaussianBlurParams;
    
    [GaussianBlurFilter InitDefaultParams:&gaussianBlurParams];
    gaussianBlurParams.mInputTexture = inParams->mInputTexture;
    gaussianBlurParams.mBorder = inParams->mBorder;
    gaussianBlurParams.mKernelSize = inParams->mKernelSize;
    gaussianBlurParams.mPremultipliedAlpha = mPremultipliedAlpha;
    gaussianBlurParams.mGenerateOutputTexture = TRUE;
    
    mGaussianBlurFilter[0] = (GaussianBlurFilter*)[(GaussianBlurFilter*)[GaussianBlurFilter alloc] InitWithParams:&gaussianBlurParams];
    
    for (int curLevel = 1; curLevel < mNumLevels; curLevel++)
    {
        gaussianBlurParams.mInputTexture = [mDownsampleFilter GetDownsampleTexture:(curLevel - 1)];
        gaussianBlurParams.mBorder = inParams->mBorder / pow(2, curLevel);
        gaussianBlurParams.mKernelSize = inParams->mKernelSize;
        gaussianBlurParams.mPremultipliedAlpha = mPremultipliedAlpha;
        gaussianBlurParams.mGenerateOutputTexture = TRUE;
        
        mGaussianBlurFilter[curLevel] = (GaussianBlurFilter*)[(GaussianBlurFilter*) [GaussianBlurFilter alloc] 
                                                                                    InitWithParams:&gaussianBlurParams];
    }
    
    TextureCreateParams createParams;
    TextureParams genericParams;
    
    [Texture InitDefaultParams:&genericParams];
    [DynamicTexture InitDefaultCreateParams:&createParams];
    
    createParams.mWidth = inParams->mInputTexture->mGLWidth;
    createParams.mHeight = inParams->mInputTexture->mGLHeight;
    createParams.mFormat = GL_RGBA;
    createParams.mType = GL_UNSIGNED_BYTE;

    mSourceTexture = inParams->mInputTexture;
    [mSourceTexture retain];
    
    mBorder = inParams->mBorder;
    
    mColorMultiplyEnabled = FALSE;
    
    for (int i = 0; i < 4; i++)
    {
        SetColor(&mColor[i], 255, 255, 255, 255);
    }
    
    mDrawBaseLayer = FALSE;
        
    return self;
}

-(void)dealloc
{
    [mDownsampleFilter release];
    [mSourceTexture release];
    
    for (int curLevel = 0; curLevel < mNumLevels; curLevel++)
    {
        [mGaussianBlurFilter[curLevel] release];
    }
    
    free(mGaussianBlurFilter);
        
    [super dealloc];
}

+(void)InitDefaultParams:(BloomGaussianParams*)outParams
{
    outParams->mInputTexture = NULL;
    outParams->mBorder = 0;
    outParams->mKernelSize = GAUSSIAN_BLUR_KERNEL_SIZE;
    outParams->mNumDownsampleLevels = DEFAULT_NUM_DOWNSAMPLE_LEVELS;
    outParams->mPremultipliedAlpha = FALSE;
}

-(void)Update:(CFTimeInterval)inTimeStep
{
    [mDownsampleFilter Update:inTimeStep];
    
    for (int curLevel = 0; curLevel < mNumLevels; curLevel++)
    {
        [mGaussianBlurFilter[curLevel] Update:inTimeStep];
    }
}

-(void)Draw
{
    float vertex[12] = {    0, 0, 0,
                            0, 1, 0,
                            1, 0, 0,
                            1, 1, 0 };
                            
    float texCoord[8] = {   0, 0,
                            0, 1,
                            1, 0,
                            1, 1  };
                                                                                
    GLState glState;
    SaveGLState(&glState);
    
    glEnable(GL_BLEND);
    
    if (mPremultipliedAlpha)
    {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    else
    {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    {        
        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        
        glPushMatrix();
        {
            if (mColorMultiplyEnabled)
            {
                glEnableClientState(GL_COLOR_ARRAY);
                
                float colorArray[16];
                                            
                for (int i = 0; i < 4; i++)
                {
                    colorArray[(4 * i) + 0] = GetRedFloat(&mColor[i]);
                    colorArray[(4 * i) + 1] = GetGreenFloat(&mColor[i]);
                    colorArray[(4 * i) + 2] = GetBlueFloat(&mColor[i]);
                    colorArray[(4 * i) + 3] = GetAlphaFloat(&mColor[i]);
                }
                            
                glColorPointer(4, GL_FLOAT, 0, colorArray);
            }
            
            glVertexPointer(3, GL_FLOAT, 0, vertex);
            glTexCoordPointer(2, GL_FLOAT, 0, texCoord);
            
            int counter = 0;
            
            for (int curLevel = (mNumLevels - 1); curLevel >= 0; curLevel--)
            {
                glPushMatrix();
                
                Texture* curTexture = [mGaussianBlurFilter[curLevel] GetOutputTexture];
                [curTexture Bind];
                
                // Every level is scaled double previous one.  So smallest level is
                // scaled by a factor of 2 ^ (count - 1)
                glScalef(   curTexture->mGLWidth * pow(2, mNumLevels - counter - 1),
                            curTexture->mGLHeight * pow(2, mNumLevels - counter - 1),
                            1.0 );


                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
                
                glPopMatrix();
                
                counter++;
            }
        }
        glPopMatrix();

        if (mDrawBaseLayer)
        {
            glPushMatrix();
            {
                [mSourceTexture Bind];
                
                glTranslatef(mBorder, mBorder, 0.0);
                glScalef(mSourceTexture->mGLWidth, mSourceTexture->mGLHeight, 1.0);
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            }
            glPopMatrix();
        }

        [Texture Unbind];
    }
    glPopMatrix();
    
    RestoreGLState(&glState);
        
    NeonGLError();
}

-(void)SetColorMultiplyEnabled:(BOOL)inEnabled
{
    mColorMultiplyEnabled = TRUE;
}

-(void)SetColor:(Color)inColor
{
    for (int i = 0; i < 4; i++)
    {
        mColor[i] = inColor;
    }
}

-(void)SetColorPerVertex:(Color*)inColors
{
    for (int i = 0; i < 4; i++)
    {
        mColor[i] = inColors[i];
    }
}

-(void)MarkCompleted
{
    [mSourceTexture release];
    mSourceTexture = NULL;
}

-(NSMutableArray*)GetTextureLayers
{
    NSMutableArray* retArray = [[NSMutableArray alloc] initWithCapacity:(mNumLevels + 1)];
    
    for (int curLevel = (mNumLevels - 1); curLevel >= 0; curLevel--)
    {
        [retArray addObject:[mGaussianBlurFilter[curLevel] GetOutputTexture]];
    }
    
    if (mSourceTexture != NULL)
    {
        [retArray addObject:mSourceTexture];
    }
    
    [retArray autorelease];
    
    return retArray;
}

-(void)SetDrawBaseLayer:(BOOL)inDrawBaseLayer
{
    mDrawBaseLayer = inDrawBaseLayer;
}

@end