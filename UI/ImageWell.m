//
//  ImageWell.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.

#import "ImageWell.h"
#import "TextureManager.h"

@implementation ImageWell

-(ImageWell*)InitWithParams:(ImageWellParams*)inParams
{
    [super Init];
    
    mOrtho = TRUE;
    
    NSAssert(inParams->mTexture != NULL, @"Trying to create and ImageWell with a NULL texture, this doesn't make sense");
        
    mTexture = inParams->mTexture;
    [mTexture retain];
    
    return self;
}

-(void)dealloc
{
    [mTexture release];

    [super dealloc];
}

-(void)DrawOrtho
{
    float vertexArray[12] = {   0, 0, 0,
                                0, 1, 0,
                                1, 0, 0,
                                1, 1, 0 };
    
    float texCoordArray[8] = {  0, 0,
                                0, 1,
                                1, 0,
                                1, 1 };
                                
    GLState glState;
    SaveGLState(&glState);
                                    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    
    glMatrixMode(GL_MODELVIEW);
    
    if (mTexture != NULL)
    {
        glPushMatrix();
        {
            [mTexture Bind];
            glScalef(mTexture->mGLWidth, mTexture->mGLHeight, 1.0f);

            glColor4f(1.0, 1.0, 1.0, mAlpha);
            glVertexPointer(3, GL_FLOAT, 0, vertexArray);
            glTexCoordPointer(2, GL_FLOAT, 0, texCoordArray);
                
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }
        glPopMatrix();
    }

    glDisable(GL_BLEND);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    
    [Texture Unbind];
    
    RestoreGLState(&glState);
}

@end