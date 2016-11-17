//
//  PVRTCTexture.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "PVRTCTexture.h"
#import "NeonMath.h"

#define PVR_TEXTURE_FLAG_TYPE_MASK    0xff

static char gPVRTexIdentifier[4] = "PVR!";

@implementation PVRTCTexture

-(Texture*)InitWithData:(NSData*)inData textureParams:(TextureParams*)inParams
{    
    NSAssert(inParams->mTextureAtlas == NULL, @"Texture atlases not supported for PVRTC textures");
    
    u32 widthBlocks = 0, heightBlocks = 0;
    u32 blockSize = 0;
    
    u32 dataLength = 0;
    
    BOOL hasAlpha = FALSE;
    u32 bpp = 0;
    
    u32 length = [inData length];
    const u8* data = (const u8*)[inData bytes];
    
    NSAssert(length >= sizeof(PVRTexHeader), @"Texture isn't even big enough to contain a header");
    
    PVRTexHeader* header = (PVRTexHeader*)data;
    memcpy(&mHeader, header, sizeof(PVRTexHeader));
    
    u32 tag = CFSwapInt32LittleToHost(header->pvrTag);
    
    if (tag != *((u32*)&gPVRTexIdentifier))
    {
        NSAssert(FALSE, @"Header doesn't contain PVRTC tag.  Is this really a PVRTC file?");
    }
    
    u32 flags = CFSwapInt32LittleToHost(header->flags);
    u32 formatFlags = flags & PVR_TEXTURE_FLAG_TYPE_MASK;
    
    mImageData = [[NSMutableArray alloc] initWithCapacity:header->numMipmaps];
    
    if (formatFlags == kPVRTextureFlagTypePVRTC_4 || formatFlags == kPVRTextureFlagTypePVRTC_2)
    {
        if (formatFlags == kPVRTextureFlagTypePVRTC_4)
        {
            mFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
        }
        else if (formatFlags == kPVRTextureFlagTypePVRTC_2)
        {
            mFormat = GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG;
        }
    
        mWidth = CFSwapInt32LittleToHost(header->width);
        mHeight = CFSwapInt32LittleToHost(header->height);
        
        mGLWidth = mWidth;
        mGLHeight = mHeight;
        
        if (CFSwapInt32LittleToHost(header->bitmaskAlpha))
        {
            hasAlpha = TRUE;
        }
        else
        {
            hasAlpha = FALSE;
        }
        
        dataLength = CFSwapInt32LittleToHost(header->dataLength);
        NSAssert(dataLength == (length - sizeof(PVRTexHeader)), @"PVRTC file doesn't have as much data as it says it does");

        data += sizeof(PVRTexHeader);
                
        u32 bytesRead = 0;
        u32 dataSize = 0;
        
        int width = mWidth;
        int height = mHeight;
        
        // Calculate the data size for each texture level and respect the minimum number of blocks
        while (bytesRead < dataLength)
        {
            if (formatFlags == kPVRTextureFlagTypePVRTC_4)
            {
                blockSize = 4 * 4; // Pixel by pixel block size for 4bpp
                widthBlocks = width / 4;
                heightBlocks = height / 4;
                bpp = 4;
            }
            else
            {
                blockSize = 8 * 4; // Pixel by pixel block size for 2bpp
                widthBlocks = width / 8;
                heightBlocks = height / 4;
                bpp = 2;
            }
            
            // Clamp to minimum number of blocks
            if (widthBlocks < 2)
            {
                widthBlocks = 2;
            }
            
            if (heightBlocks < 2)
            {
                heightBlocks = 2;
            }

            dataSize = widthBlocks * heightBlocks * ((blockSize  * bpp) / 8);
            
            [mImageData addObject:[NSData dataWithBytes:data + bytesRead length:dataSize]];
            
            bytesRead += dataSize;
            
            width = MAX(width >> 1, 1);
            height = MAX(height >> 1, 1);
        }
    }
    else
    {
        NSAssert(FALSE, @"PVRTC file doesn't have a known format.  Was the correct type specified during export?");
    }
    
    [self CreateGLTexture];
    
    return self;
}

-(void)CreateGLTexture
{
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glGenTextures(1, &mTexName);
    glBindTexture(GL_TEXTURE_2D, mTexName);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLenum minFilter = mHeader.numMipmaps > 0 ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR;
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, 
                    GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, 
                    minFilter);
        
    int useWidth = mWidth;
    int useHeight = mHeight;
    int curLevel = 0;
    
    for (NSData* curData in mImageData)
    { 
        glCompressedTexImage2D(GL_TEXTURE_2D, curLevel, mFormat, useWidth, 
                    useHeight, 0, [curData length], [curData bytes]);
                    
        useWidth = max(1, useWidth >> 1);
        useHeight = max(1, useHeight >> 1);
        curLevel++;
    }
                
    NeonGLError();
}

@end

#endif