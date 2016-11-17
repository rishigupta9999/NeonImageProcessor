/*
 *  GLHelper.m
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */
 
#import "GLHelper.h"

static GLHelper* sInstance = NULL;

@implementation GLHelper

-(GLHelper*)Init
{
    mActiveFramebuffer = 0;
    mActiveRenderbuffer = 0;
    
    return self;
}

-(void)dealloc
{
    [super dealloc];
}

+(void)CreateInstance
{
    NSAssert(sInstance == NULL, @"Attempting to double-create GLHelper.");
    
    if (sInstance == NULL)
    {
        sInstance = [[GLHelper alloc] Init];
    }
}

+(void)DestroyInstance
{
    NSAssert(sInstance != NULL, @"GLHelper has already been deleted.");
    
    [sInstance release];
}

+(GLHelper*)GetInstance
{
    return sInstance;
}

-(void)InitializeDrawableWithWidth:(int)inWidth height:(int)inHeight
{
    if (mActiveFramebuffer != 0)
    {
        glDeleteFramebuffers(1, &mActiveFramebuffer);
    }
    
    if (mActiveRenderbuffer != 0)
    {
        glDeleteRenderbuffers(1, &mActiveRenderbuffer);
    }
    
    glGenFramebuffers(1, &mActiveFramebuffer);
    glGenRenderbuffers(1, &mActiveRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, mActiveFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, mActiveRenderbuffer);
    
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, inWidth, inHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, mActiveRenderbuffer);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSAssert(FALSE, @"Framebuffer unexpectedly incomplete.");
    }

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    glOrtho(0.0, (float)inWidth, 0.0, (float)inHeight, -1.0, 1.0);
    glViewport(0.0, 0.0, inWidth, inHeight);

    NeonGLError();
}

@end