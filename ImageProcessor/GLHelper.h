/*
 *  GLHelper.h
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */
 
@interface GLHelper : NSObject
{
    GLuint  mActiveFramebuffer;
    GLuint  mActiveRenderbuffer;
}

-(GLHelper*)Init;
-(void)dealloc;

+(void)CreateInstance;
+(void)DestroyInstance;
+(GLHelper*)GetInstance;

-(void)InitializeDrawableWithWidth:(int)inWidth height:(int)inHeight;

@end