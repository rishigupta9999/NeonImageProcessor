//
//  BloomBoxFilter.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "BloomBoxFilter.h"
#import "DownsampleFilter.h"
#import "DynamicTexture.h"

#import "NeonMath.h"

@implementation BloomBoxFilter

-(Filter*)InitWithTexture:(Texture*)inTexture
{
    [super Init];
    
    mSourceTexture = inTexture;
    
    TextureCreateParams createParams;
    TextureParams       genericParams;
    
    [DynamicTexture InitDefaultCreateParams:&createParams];
    [Texture InitDefaultParams:&genericParams];
    
    // Create the destination texture
    createParams.mHeight = inTexture->mGLHeight;
    createParams.mWidth = inTexture->mGLWidth;
    
    mDestTexture = [[DynamicTexture alloc] InitWithCreateParams:&createParams genericParams:&genericParams];
    
    int numLevels = log(max(inTexture->mGLHeight, inTexture->mGLWidth)) / log(2.0);
    mNumTaps = min(numLevels, MAX_BLOOM_BOX_FILTER_TAPS);
    
    mDownsampleFilter = (DownsampleFilter*)[[DownsampleFilter alloc] InitWithTexture:mSourceTexture numLevels:mNumTaps];
    
    NSAssert(mNumTaps == [mDownsampleFilter GetNumLevels], @"Number of taps isn't equal to the number of levels in the downsample filter.  This shouldn't happen.");
    
    mScratchTextures = malloc(sizeof(Texture*) * (mNumTaps + 1));
    memset(mScratchTextures, 0, sizeof(Texture*) * (mNumTaps + 1));
        
    // Bind destination texture to a framebuffer
    
    GLState glState;
    SaveGLState(&glState);

    glGenFramebuffersOES(1, &mDestFB);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, mDestFB);
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, mDestTexture->mTexName, 0);
    
    RestoreGLState(&glState);
    
    NeonGLError();
    
    return self;
}

-(void)dealloc
{
    [mDownsampleFilter release];
    [mDestTexture release];
    
    glDeleteFramebuffersOES(1, &mDestFB);
    
    [super dealloc];
}

-(void)Update:(CFTimeInterval)inTimeStep
{
    [super Update:inTimeStep];
    
    [mDownsampleFilter Update:inTimeStep];
                    
    float vertex[12] = {    0, 0, 0,
                            0, 1, 0,
                            1, 0, 0,
                            1, 1, 0 };
                                                                                
    GLState glState;
    SaveGLState(&glState);
                            
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    glVertexPointer(3, GL_FLOAT, 0, vertex);
                
    glMatrixMode(GL_MODELVIEW);    
    glPushMatrix();
    {
        glLoadIdentity();
        
        glMatrixMode(GL_PROJECTION);
        
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        glPushMatrix();
        {
            glOrthof(0.0, 1.0, 0.0, 1.0, -1.0, 1.0);
            glDisable(GL_DEPTH_TEST);
            glDisable(GL_CULL_FACE);
            glDisable(GL_LIGHTING);
                        
            glClearColor(0.0, 0.0, 0.0, 0.0);
                        
            glBindFramebufferOES(GL_FRAMEBUFFER_OES, mDestFB);
            glViewport(0, 0, mSourceTexture->mGLWidth, mSourceTexture->mGLHeight);
            
            glClear(GL_COLOR_BUFFER_BIT);
            glActiveTexture(GL_TEXTURE0);
            
            // Set up an array of source texture taps
            
            mScratchTextures[0] = mSourceTexture;
            
            for (int curLevel = 0; curLevel < mNumTaps; curLevel++)
            {
                mScratchTextures[curLevel + 1] = [mDownsampleFilter GetDownsampleTexture:curLevel];
            }
            
            for (int curTap = (mNumTaps - 1); curTap >= 0; curTap--)
            {
                // Sample between texels for additional blurring, on all but the last level
                float texelOffsetX = 1.0 / (mScratchTextures[curTap]->mGLWidth * 2);
                float texelOffsetY = 1.0 / (mScratchTextures[curTap]->mGLHeight * 2);
                
                if (curTap == 0)
                {
                    texelOffsetX = 0;
                    texelOffsetY = 0;
                }
                
                float texCoord[8] = {   texelOffsetX, texelOffsetY,
                                        texelOffsetX, 1 + texelOffsetY,
                                        1 + texelOffsetX, texelOffsetY,
                                        1 + texelOffsetX, 1 + texelOffsetY  };
                                        
                glTexCoordPointer(2, GL_FLOAT, 0, texCoord);

                [mScratchTextures[curTap] Bind];
                
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            }
                                    
        }
        glPopMatrix();

        glDisable(GL_BLEND);
        
        glMatrixMode(GL_MODELVIEW);
    }
    glPopMatrix();
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        
    [Texture Unbind];
    
    RestoreGLState(&glState);
        
    NeonGLError();
}

-(Texture*)GetDestTexture
{
    return mDestTexture;
}

@end