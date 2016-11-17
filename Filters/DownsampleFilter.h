//
//  DownsampleFilter.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "Filter.h"

@interface DownsampleFilter : Filter
{
    GLuint*     mDownsampleFBs;
    Texture*    mSourceTexture;
    Texture**   mDownsampleTextures;
    
    u32         mNumLevels;
}

-(Filter*)InitWithTexture:(Texture*)inTexture numLevels:(int)inNumLevels;
-(void)dealloc;

-(void)Update:(CFTimeInterval)inTimeStep;
-(Texture*)GetDownsampleTexture:(u32)inTextureNum;
-(u32)GetNumLevels;

@end