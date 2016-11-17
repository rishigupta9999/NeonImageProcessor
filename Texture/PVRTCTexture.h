//
//  PVRTCTexture.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "Texture.h"

enum
{
    kPVRTextureFlagTypePVRTC_2 = 24,
    kPVRTextureFlagTypePVRTC_4
};

typedef struct
{
    uint32_t headerLength;
    uint32_t height;
    uint32_t width;
    uint32_t numMipmaps;
    uint32_t flags;
    uint32_t dataLength;
    uint32_t bpp;
    uint32_t bitmaskRed;
    uint32_t bitmaskGreen;
    uint32_t bitmaskBlue;
    uint32_t bitmaskAlpha;
    uint32_t pvrTag;
    uint32_t numSurfs;
} PVRTexHeader;

@interface PVRTCTexture : Texture
{
    NSMutableArray* mImageData;
    PVRTexHeader    mHeader;
}

-(Texture*)InitWithData:(NSData*)inData textureParams:(TextureParams*)inParams;
-(void)CreateGLTexture;

@end

#endif