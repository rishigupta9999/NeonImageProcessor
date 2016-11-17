/*
 *  Neon21_ImageProcessor_Prefix.h
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */

//
// Prefix header for all source files of the 'Neon21' target in the 'Neon21' project
//

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OpenGL/gl.h>

#import "NeonTypes.h"
#import "NeonUtilities.h"

#define glGenFramebuffersOES        glGenFramebuffers
#define glBindFramebufferOES        glBindFramebuffer
#define glFramebufferTexture2DOES   glFramebufferTexture2D
#define glDeleteFramebuffersOES     glDeleteFramebuffers
#define glOrthof                    glOrtho
#define glCheckFramebufferStatusOES glCheckFramebufferStatus

#define GL_FRAMEBUFFER_OES          GL_FRAMEBUFFER
#define GL_FRAMEBUFFER_COMPLETE_OES GL_FRAMEBUFFER_COMPLETE
#define GL_COLOR_ATTACHMENT0_OES    GL_COLOR_ATTACHMENT0
#define GL_FRAMEBUFFER_BINDING_OES  GL_FRAMEBUFFER_BINDING

#endif