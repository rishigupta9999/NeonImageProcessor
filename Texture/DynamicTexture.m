//
//  DynamicTexture.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "DynamicTexture.h"

@implementation DynamicTexture

+(void)InitDefaultCreateParams:(TextureCreateParams*)outParams
{
    outParams->mWidth = 0;
    outParams->mHeight = 0;
    outParams->mFormat = GL_RGBA;
    outParams->mType = GL_UNSIGNED_BYTE;
}

-(Texture*)InitWithCreateParams:(TextureCreateParams*)inCreateParams genericParams:(TextureParams*)inGenericParams
{
    [self InitWithData:NULL textureParams:inGenericParams];
    
    memcpy(&mCreateParams, inCreateParams, sizeof(TextureCreateParams));
    
    glGenTextures(1, &mTexName);
    glBindTexture(GL_TEXTURE_2D, mTexName);
    
    int widthPow2 = mCreateParams.mWidth;
    int heightPow2 = mCreateParams.mHeight;
    
    float widthLog = log(mCreateParams.mWidth) / log(2.0);
    float heightLog = log(mCreateParams.mHeight) / log(2.0);
    
    if ((widthLog != (int)(widthLog)) || (heightLog != (int)heightLog))
    {
        widthPow2 = pow(2, ceil(widthLog));
        heightPow2 = pow(2, ceil(heightLog));
    }
    
    mWidth = mCreateParams.mWidth;
    mHeight = mCreateParams.mHeight;
    mGLWidth = widthPow2;
    mGLHeight = heightPow2;
    
    glTexImage2D(GL_TEXTURE_2D, 0, mCreateParams.mFormat, mGLWidth, mGLHeight, 0, mCreateParams.mFormat, mCreateParams.mType, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
    return self;
}

@end