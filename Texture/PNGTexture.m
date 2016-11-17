#import "PNGTexture.h"
#import "PNGUtilities.h"

static void PngReadFunction(png_struct* inPngPtr, png_byte* outData, png_size_t inLength);

@implementation PNGTexture

-(Texture*)InitWithData:(NSData*)inData textureParams:(TextureParams*)inParams
{
    [super InitWithData:(inData) textureParams:inParams];
    
    PNGInfo pngInfo;
    ReadPNGData(inData, inParams->mTexAddressing, &pngInfo);
        
    mWidth = pngInfo.mWidth;
    mHeight = pngInfo.mHeight;
    mTexBytes = (u32*)pngInfo.mImageData;
        
    // Create the OpenGL texture object
    [self CreateGLTexture];
    
    return self;
}

-(Texture*)InitWithMipMapData:(NSMutableArray*)inData textureParams:(TextureParams*)inParams
{
    [super InitWithMipMapData:inData textureParams:inParams];
    
    for (int curLevel = 0; curLevel < [inData count]; curLevel++)
    {
        PNGInfo pngInfo;
        ReadPNGData((NSData*)[inData objectAtIndex:curLevel], inParams->mTexAddressing, &pngInfo);

        if (curLevel == 0)
        {
            mWidth = pngInfo.mWidth;
            mHeight = pngInfo.mHeight;
            
#if NEON_DEBUG
            int numLevels = max(log(mWidth) / log(2.0), log(mHeight) / log(2.0)) + 1;
            NSAssert(numLevels == [inData count], @"Invalid number of mipmap levels provided");
#endif
        }
        
        [self SetMipMapData:(u32*)pngInfo.mImageData level:curLevel];
    }
    
    [self CreateGLTexture];

    return self;
}

-(void)dealloc
{
    [super dealloc];
}

@end
