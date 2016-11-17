//
//  DownsampleFilter.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "DownsampleFilter.h"
#import "DynamicTexture.h"
#import "NeonMath.h"

#define DUMP_DEBUG_IMAGES   (0)

@implementation DownsampleFilter

-(Filter*)InitWithTexture:(Texture*)inTexture numLevels:(int)inNumLevels
{
    [super Init];
    
    GLState glState;
    
    SaveGLState(&glState);
    
    mSourceTexture = inTexture;
        
    TextureCreateParams createParams;
    TextureParams       genericParams;
    
    [DynamicTexture InitDefaultCreateParams:&createParams];
    [Texture InitDefaultParams:&genericParams];
            
    int numLevels = log(max(inTexture->mGLHeight, inTexture->mGLWidth)) / log(2.0);
    mNumLevels = min(numLevels, inNumLevels);
    
    NSAssert(mNumLevels > 0, @"Can't downsample this texture because it is too small");
    
    int width = inTexture->mGLWidth / 2;
    int height = inTexture->mGLHeight / 2;
        
    mDownsampleTextures = malloc(sizeof(Texture*) * mNumLevels);
    mDownsampleFBs = malloc(sizeof(GLuint) * mNumLevels);
    
    for (int curDownsample = 0; curDownsample < mNumLevels; curDownsample++)
    {
        createParams.mFormat = GL_RGBA;
        createParams.mType = GL_UNSIGNED_BYTE;
        
        createParams.mWidth = max(MIN_FRAMEBUFFER_DIMENSION, width);
        createParams.mHeight = max(MIN_FRAMEBUFFER_DIMENSION, height);
        
        mDownsampleTextures[curDownsample] = [[DynamicTexture alloc] InitWithCreateParams:&createParams genericParams:&genericParams];
        
        mDownsampleTextures[curDownsample]->mWidth = width;
        mDownsampleTextures[curDownsample]->mHeight = height;
        
        width /= 2;
        height /= 2;
    }
        
    // Bind small textures to framebuffers
    glGenFramebuffersOES(mNumLevels, mDownsampleFBs);
    
    for (int curFB = 0; curFB < mNumLevels; curFB++)
    {
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, mDownsampleFBs[curFB]);
        glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, mDownsampleTextures[curFB]->mTexName, 0);
        
        NSAssert(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES, @"Incomplete framebuffer");
    }
    
    RestoreGLState(&glState);
    
    NeonGLError();
    
    return self;
}

-(void)dealloc
{    
    glDeleteFramebuffersOES(mNumLevels, mDownsampleFBs);
    
    for (int curLevel = 0; curLevel < mNumLevels; curLevel++)
    {
        [mDownsampleTextures[curLevel] release];
    }
    
    free(mDownsampleTextures);
    free(mDownsampleFBs);
    
    [super dealloc];
}

-(void)Update:(CFTimeInterval)inTimeStep
{
    [super Update:inTimeStep];
    
    float vertex[12] = {    0, 0, 0,
                            0, 1, 0,
                            1, 0, 0,
                            1, 1, 0 };
                            
    float texCoord[8] = {   0, 0,
                            0, 1,
                            1, 0,
                            1, 1    };
                                                    
    GLState glState;
    SaveGLState(&glState);
                            
    [mSourceTexture Bind];
    
#if DUMP_DEBUG_IMAGES
    [mSourceTexture DumpContents];
#endif
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    glVertexPointer(3, GL_FLOAT, 0, vertex);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoord);
                
    glMatrixMode(GL_MODELVIEW);    
    glPushMatrix();
    {
        glLoadIdentity();
        
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        glPushMatrix();
        {
            glOrthof(0.0, 1.0, 0.0, 1.0, -1.0, 1.0);
            
            glDisable(GL_DEPTH_TEST);
            glDisable(GL_CULL_FACE);
            glDisable(GL_LIGHTING);
            
            int width = max(mSourceTexture->mGLWidth / 2, 1);
            int height = max(mSourceTexture->mGLHeight / 2, 1);
            
            glClearColor(0.0, 0.0, 0.0, 0.0);
            
            for (int curLevel = 0; curLevel < mNumLevels; curLevel++)
            {
                glBindFramebufferOES(GL_FRAMEBUFFER_OES, mDownsampleFBs[curLevel]);
                
                glViewport(0, 0, width, height);
                glClear(GL_COLOR_BUFFER_BIT);                                
                
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
                                                
                width = max(width / 2, 1);
                height = max(height / 2, 1);
                
#if DUMP_DEBUG_IMAGES
                SaveScreen(@"output.png");
#endif
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

-(Texture*)GetDownsampleTexture:(u32)inTextureNum
{
    NSAssert(inTextureNum < mNumLevels, @"Too high a texture level specified");
    
    return mDownsampleTextures[inTextureNum];
}

-(u32)GetNumLevels
{
    return mNumLevels;
}

@end