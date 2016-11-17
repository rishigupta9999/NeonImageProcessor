//
//  DynamicTexture.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "Texture.h"

typedef struct
{
    u32     mWidth;
    u32     mHeight;
    GLenum  mFormat;
    GLenum  mType;
} TextureCreateParams;

@interface DynamicTexture : Texture
{
    TextureCreateParams   mCreateParams;
}

+(void)InitDefaultCreateParams:(TextureCreateParams*)outParams;

-(Texture*)InitWithCreateParams:(TextureCreateParams*)inCreateParams genericParams:(TextureParams*)inGenericParams;

@end