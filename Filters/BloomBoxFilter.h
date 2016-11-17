//
//  BloomBoxFilter.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "Filter.h"

#define MAX_BLOOM_BOX_FILTER_TAPS   (2)

@class DownsampleFilter;

@interface BloomBoxFilter : Filter
{
    DownsampleFilter*   mDownsampleFilter;
    Texture*            mSourceTexture;
    Texture*            mDestTexture;
    Texture**           mScratchTextures;
    
    GLuint              mDestFB;
    
    int                 mNumTaps;
}

-(Filter*)InitWithTexture:(Texture*)inTexture;
-(void)dealloc;

-(void)Update:(CFTimeInterval)inTimeStep;
-(Texture*)GetDestTexture;

@end