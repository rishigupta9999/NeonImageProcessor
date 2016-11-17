//
//  Texture.m
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "Texture.h"
#import "NeonMath.h"

#define TEXTURE_MAX_LEVEL_DEFAULT   (-1)

@implementation Texture

-(Texture*)Init
{
    mTexBytes = NULL;
    mMipMapTexBytes = NULL;
    mTexName = 0;
        
    mGLWidth = 0;
    mGLHeight = 0;
    
    mWidth = 0;
    mHeight = 0;
    
    mMaxWidth = 0;
    mMaxHeight = 0;
    
    mFormat = GL_RGBA;
    mType = GL_UNSIGNED_BYTE;
    
    mPremultipliedAlpha = FALSE;
    
    mDebugName = NULL;
    
    [TextureAtlas InitTextureAtlasInfo:&mTextureAtlasInfo];
    
    [Texture InitDefaultParams:&mParams];
    
    return self;
}

-(void)dealloc
{
    if (mParams.mTextureAtlas == NULL)
    {
        glDeleteTextures(1, &mTexName);
    }
    
    if (mTexBytes != NULL)
    {
        free(mTexBytes);
    }
    
    if (mDebugName != NULL)
    {
        [mDebugName release];
    }
    
    [self FreeMipMapLayers];
    
	[super dealloc];
}

-(void)FreeMipMapLayers
{
    if (mMipMapTexBytes != NULL)
    {
        int numLevels = [self GetNumMipMapLevels];
        
        for (int i = 0; i < numLevels; i++)
        {
            if (mMipMapTexBytes[i] != NULL)
            {
                free(mMipMapTexBytes[i]);
            }
        }
        
        free(mMipMapTexBytes);
        mMipMapTexBytes = NULL;
    }
    
    if (mSrcMipMapTexBytes != NULL)
    {
        int numLevels = [self GetNumSrcMipMapLevels];
        
        for (int i = 0; i < numLevels; i++)
        {
            if (mSrcMipMapTexBytes[i] != NULL)
            {
                free(mSrcMipMapTexBytes[i]);
            }
        }
        
        free(mSrcMipMapTexBytes);
        mSrcMipMapTexBytes = NULL;
    }
}

-(void)CreateGLTexture
{
    if (mParams.mTextureAtlas != NULL)
    {
        mGLWidth = mWidth;
        mGLHeight = mHeight;
        
        return;
    }
    
    NeonGLError();
    
    if ((mGLWidth == 0) || (mGLHeight == 0))
    {
        mGLWidth = mWidth;
        mGLHeight = mHeight;
    }
    
    // We're dealing with OpenGL ES 1.1 here, need Power of 2 textures.
    [self VerifyDimensions];
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glGenTextures(1, &mTexName);
    glBindTexture(GL_TEXTURE_2D, mTexName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, mParams.mMagFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, mParams.mMinFilter);
                   
    NeonGLError();

    BOOL mipMappingEnabled =    (mParams.mMinFilter == GL_LINEAR_MIPMAP_LINEAR) ||
                                (mParams.mMinFilter == GL_LINEAR_MIPMAP_NEAREST) ||
                                (mParams.mMinFilter == GL_NEAREST_MIPMAP_LINEAR) ||
                                (mParams.mMinFilter == GL_NEAREST_MIPMAP_NEAREST);
                                
    if (mipMappingEnabled)
    {
        NSAssert(mMipMapTexBytes != NULL, @"No mipmap texture levels were specified");
        
        int numLevels = [self GetNumMipMapLevels];
        
        int curWidth = mGLWidth;
        int curHeight = mGLHeight;
        
        for (int curLevel = 0; curLevel < numLevels; curLevel++)
        {
            glTexImage2D(GL_TEXTURE_2D, curLevel, GL_RGBA, curWidth, 
                        curHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 
                        mMipMapTexBytes[curLevel]);
                        
            curWidth /= 2;
            curHeight /= 2;
        }
    }
    else
    {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, mGLWidth, 
                    mGLHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 
                    mTexBytes);
    }
    
    NeonGLError();
    
    if (mParams.mTexDataLifetime == TEX_DATA_DISPOSE)
    {
        free(mTexBytes);
        mTexBytes = NULL;
    }
    
    [self FreeMipMapLayers];
    
    // We don't want the texture bound by default.  Unbind it - we'll bind it explicitly in the model.
    glBindTexture(GL_TEXTURE_2D, 0);
    
    NeonGLError();
}

-(void)Bind
{
    NSAssert(mTexName != 0, @"There is no OpenGL texture object associated with this texture");
    
    glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, mTexName);
}

+(void)Unbind
{
    glDisable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, 0);
}

-(Texture*)InitWithBytes:(unsigned char*)inBytes bufferSize:(u32)inBufferSize textureParams:(TextureParams*)inParams
{
    mTexBytes = NULL;
    mFileLength = inBufferSize;
    mTexName = 0;
    
    memcpy(&mParams, inParams, sizeof(TextureParams));
        
    return self;
}

-(Texture*)InitWithData:(NSData*)inData textureParams:(TextureParams*)inParams
{
    mTexBytes = NULL;
    mFileLength = [inData length];
    mTexName = 0;
    
    memcpy(&mParams, inParams, sizeof(TextureParams));
        
    return self;
}

-(Texture*)InitWithMipMapData:(NSMutableArray*)inData textureParams:(TextureParams*)inParams
{
    mTexBytes = NULL;
    mFileLength = 0;
    mTexName = 0;
    
    memcpy(&mParams, inParams, sizeof(TextureParams));
        
    return self;

}

+(void)InitDefaultParams:(TextureParams*)outParams
{
    outParams->mTexAddressing = TEX_ADDRESSING_8;
    outParams->mTexDataLifetime = TEX_DATA_RETAIN;
    outParams->mTextureAtlas = NULL;
    outParams->mMagFilter = GL_LINEAR;
    outParams->mMinFilter = GL_LINEAR;
}

+(void)RoundToValidDimensionsWidth:(u32)inWidth Height:(u32)inHeight ValidWidth:(u32*)outWidth ValidHeight:(u32*)outHeight
{
    u32 maskedWidth = inWidth & (inWidth - 1);
    u32 maskedHeight = inHeight & (inHeight - 1);
    
    if (maskedWidth == 0)
    {
        *outWidth = inWidth;
    }
    else
    {
        int count = 0;
        
        while (inWidth > 0)
        {
            inWidth >>= 1;
            count++;
        }
        
        *outWidth = (1 << count);
    }
    
    if (maskedHeight == 0)
    {
        *outHeight = inHeight;
    }
    else
    {
        int count = 0;
        
        while (inHeight > 0)
        {
            inHeight >>= 1;
            count++;
        }
        
        *outHeight = (1 << count);
    }
}

-(void)VerifyDimensions
{
    BOOL validHeight = TRUE;
    BOOL validWidth = TRUE;
    
    double heightPow = log2(mGLHeight);
    double widthPow = log2(mGLWidth);
    
    if (heightPow != (int)heightPow)
    {
        validHeight = FALSE;
    }
    
    if (widthPow != (int)widthPow)
    {
        validWidth = FALSE;
    }

    if (!validHeight || !validWidth)
    {
        // Have to pad out the texture to a power of 2 size

        if (mMipMapTexBytes != NULL)
        {            
            int curSrcWidth = mWidth;
            int curSrcHeight = mHeight;
            int curDestWidth = pow(2, (int)ceil(widthPow));
            int curDestHeight = pow(2, (int)ceil(heightPow));
            
            mGLWidth = curDestWidth;
            mGLHeight = curDestHeight;
            
            int numLevels = [self GetNumMipMapLevels];

            for (int curLevel = 0; curLevel < numLevels; curLevel++)
            {
                u32 textureLayerIndex = [self GetTextureLayerIndexForMipMapLevel:curLevel];
                
                curSrcWidth = mWidth / pow(2, textureLayerIndex);
                curSrcHeight = mHeight / pow(2, textureLayerIndex);
                
                u32* newTex = [self PadTextureData:mSrcMipMapTexBytes[textureLayerIndex] srcWidth:curSrcWidth srcHeight:curSrcHeight
                                    destWidth:curDestWidth destHeight:curDestHeight];
                
                mMipMapTexBytes[curLevel] = newTex;
                
                curDestWidth /= 2;
                curDestHeight /= 2;
            }
        }
        else
        {
            int newHeight = pow(2, (int)ceil(heightPow));
            int newWidth = pow(2, (int)ceil(widthPow));

            u32* newTex = [self PadTextureData:mTexBytes srcWidth:mWidth srcHeight:mHeight destWidth:newWidth destHeight:newHeight];
            
            mGLWidth = newWidth;
            mGLHeight = newHeight;
            
            free(mTexBytes);
            mTexBytes = newTex;
        }
    }
}

-(u32*)PadTextureData:(u32*)inTexData srcWidth:(u32)inSrcWidth srcHeight:(u32)inSrcHeight destWidth:(u32)inDestWidth destHeight:(u32)inDestHeight
{
    u32* newTex = malloc(inDestHeight * inDestWidth * 4);
    memset(newTex, 0, inDestHeight * inDestWidth * 4);
    
    for (int y = 0; y < inSrcHeight; y++)
    {
        for (int x = 0; x < inDestWidth; x++)
        {
            // Preserve the byte ordering - just do copies of the longs.  Little or big endian will stay the same
            
            int sourceByte = x + (y * inSrcWidth);
            int destByte = x + (y * inDestWidth);
            
            u32 source = 0;
            
            if (x < inSrcWidth)
            {
                source = inTexData[sourceByte];
            }
            
            newTex[destByte] = source;
        }
    }
    
    return newTex;
}

-(u32)GetTexel:(CGPoint*)inPoint
{
    u32 retVal = 0;
    
    if (mTexBytes != 0)
    {
        int x = (int)inPoint->x;
        int y = (int)inPoint->y;
        
        BOOL valid = (x >= 0) && (y >= 0) && (x < mWidth) && (y < mHeight);
        NSAssert(valid, @"Point out of texture bounds, no corresponding texel.");
        
        int readIndex = x + (y * mGLWidth);
        
        retVal = CFSwapInt32BigToHost(mTexBytes[readIndex]);
    }
    else
    {
        NSAssert(FALSE, @"mTexData was NULL, when creating the texture, indicate that mTexData should not be freed.\n");
    }
    
    return retVal;
}

-(void)FreeClientData
{
    if (mTexBytes != NULL)
    {
        free(mTexBytes);
    }
    
    mTexBytes = NULL;
}

-(u32)GetSizeBytes
{
    u32 texelSize = GetNumChannels(mFormat) * GetTypeSize(mType);
    
    return (mGLHeight * mGLWidth * texelSize);
}

-(void)WritePPM:(NSString*)inFileName
{
    DumpPPM((unsigned int*)mTexBytes, [inFileName cStringUsingEncoding:NSASCIIStringEncoding], mGLWidth, mGLHeight);
}

-(void)SetMaxWidth:(u32)inWidth
{
    NSAssert(inWidth >= mWidth, @"Trying to set a max width smaller than already existing width.");
    mMaxWidth = inWidth;
}

-(u32)GetMaxWidth
{
    u32 width = mWidth;
    
    if (mMaxWidth != 0)
    {
        NSAssert(mMaxWidth >= mWidth, @"Max width is smaller than width.  This is illogical.");
        width = mMaxWidth;
    }
    
    return width;
}

-(void)SetMaxHeight:(u32)inHeight
{
    NSAssert(inHeight >= mHeight, @"Trying to set a max height smaller than already existing height.");
    mMaxHeight = inHeight;
}

-(u32)GetMaxHeight
{
    u32 height = mHeight;
    
    if (mMaxHeight != 0)
    {
        NSAssert(mMaxWidth >= mWidth, @"Max height is smaller than height.  This is illogical.");
        height = mMaxHeight;
    }
    
    return height;
}

-(void)SetMipMapData:(u32*)inData level:(u32)inLevel
{
    int numLevels = max(log(mWidth) / log(2.0), log(mHeight) / log(2.0)) + 1;
    
    NSAssert(inLevel < numLevels, @"Trying to specify an invalid mipmap level");

    if (inLevel == 0)
    {
        NSAssert(mSrcMipMapTexBytes == NULL, @"Attempting to respecify base level.  This is currently unsupported.");
        
        mSrcMipMapTexBytes = malloc(sizeof(u32*) * numLevels);
        memset(mSrcMipMapTexBytes, 0, sizeof(u32*) * numLevels);
        
        double heightPow = log2(mHeight);
        double widthPow = log2(mWidth);
        
        numLevels = max(ceil(widthPow), ceil(heightPow)) + 1;

        mMipMapTexBytes = malloc(sizeof(u32*) * numLevels);
        memset(mMipMapTexBytes, 0, sizeof(u32*) * numLevels);
    }
    
    mSrcMipMapTexBytes[inLevel] = inData;
}

-(void)SetMagFilter:(GLenum)inMagFilter minFilter:(GLenum)inMinFilter
{
    mParams.mMagFilter = inMagFilter;
    mParams.mMinFilter = inMinFilter;
    
    GLState glState;
    SaveGLState(&glState);
    
    glBindTexture(GL_TEXTURE_2D, mTexName);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, mParams.mMagFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, mParams.mMinFilter);
    
    RestoreGLState(&glState);
}

-(u32)GetNumMipMapLevels
{
    return (max(log(mGLWidth) / log(2.0), log(mGLHeight) / log(2.0)) + 1);
}

-(u32)GetNumSrcMipMapLevels
{
    return (max(log(mWidth) / log(2.0), log(mHeight) / log(2.0)) + 1);
}

-(u32)GetTextureLayerIndexForMipMapLevel:(u32)inMipMapLevel
{
    // Find the largest texture layer that fits into this mipmap level
    
    int numLevels = [self GetNumMipMapLevels];
    
    int desiredWidth = mGLWidth / pow(2, inMipMapLevel);
    int desiredHeight = mGLHeight / pow(2, inMipMapLevel);
    
    int layerWidth = mWidth;
    int layerHeight = mHeight;
    
    int retIndex = -1;
    
    for (int curLevel = 0; curLevel < numLevels; curLevel++)
    {
        if ((layerWidth <= desiredWidth) && (layerHeight <= desiredHeight))
        {
            retIndex = curLevel;
            break;
        }
        
        layerWidth /= 2;
        layerHeight /= 2;
    }
    
    NSAssert(retIndex != -1, @"No texture layer that fits within the mipmap level was found");
    
    return retIndex;
}

-(void)DumpContents
{
    GLState glState;
    
    SaveGLState(&glState);
    
    GLuint fb;
    glGenFramebuffersOES(1, &fb);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, fb);
    
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, mTexName, 0);
    
    SaveScreenRect(@"TextureAtlas.png", mGLWidth, mGLHeight);
    
    RestoreGLState(&glState);
}

-(NSString*)GetDebugName
{
    return mDebugName;
}

-(void)SetDebugName:(NSString*)inString
{
    [mDebugName release];
    mDebugName = [inString retain];
}

@end