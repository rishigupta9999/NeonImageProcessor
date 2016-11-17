//
//  TextureAtlas.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#define TEXTURE_ATLAS_DEFAULT_CAPACITY  (4)

#define DUMP_TEXTURE_NAMES              (0)
#define DUMP_SCANLINE_INFO              (0)
#define DUMP_DEBUG_IMAGE                (0)

#define UNLIMITED_HEIGHT                (-1)
#define UNLIMITED_WIDTH                 (-1)

#import "TextureAtlas.h"
#import "Texture.h"
#import "TextTextureBuilder.h"
#import "NeonMath.h"
#import "PNGUtilities.h"

@implementation ScanlineEntry

-(void)dealloc
{
    [mTextures release];
    [super dealloc];
}

@end

@implementation TextureAtlasEntry

-(TextureAtlasEntry*)Init
{
    mTexture = NULL;
    return self;
}

-(void)SetTexture:(Texture*)inTexture
{
    mTexture = inTexture;
}

@end

@implementation TextureAtlas

-(TextureAtlas*)InitWithParams:(TextureAtlasParams*)inParams
{
    mTextureList = [[NSMutableArray alloc] initWithCapacity:TEXTURE_ATLAS_DEFAULT_CAPACITY];
    mTextureObject = 0;
    mAtlasWidth = 0;
    mAtlasHeight = 0;
    
    return self;
}

-(void)dealloc
{
    [mTextureList release];
    
    glDeleteTextures(1, &mTextureObject);
    
    [super dealloc];
}

+(void)InitDefaultParams:(TextureAtlasParams*)outParams
{
    outParams->mWidth = TEXTURE_ATLAS_DIMENSION_INVALID;
    outParams->mHeight = TEXTURE_ATLAS_DIMENSION_INVALID;
}

+(void)InitTextureAtlasInfo:(TextureAtlasInfo*)outInfo
{
    outInfo->mX = 0;
    outInfo->mY = 0;
    
    outInfo->mSMin = 0.0f;
    outInfo->mTMin = 0.0f;
    
    outInfo->mSMax = 0.0f;
    outInfo->mTMax = 0.0f;
    
    outInfo->mPlaced = FALSE;
}

-(void)AddTexture:(Texture*)inTexture
{
    TextureAtlasEntry* atlasEntry = [(TextureAtlasEntry*)[TextureAtlasEntry alloc] Init];
    
    [atlasEntry SetTexture:inTexture];
    
    // Textures are sorted in descending width
    
    int replaceIndex = 0;
    
    for (TextureAtlasEntry* curEntry in mTextureList)
    {
        if ([curEntry->mTexture GetMaxWidth] < [inTexture GetMaxWidth])
        {
            break;
        }
        
        replaceIndex++;
    }
    
    [mTextureList insertObject:atlasEntry atIndex:replaceIndex];
    [atlasEntry release];
}

-(void)CreateAtlas
{
#if DUMP_TEXTURE_NAMES
    [self DumpTextureNames];
#endif

    GLint maxDimension = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxDimension);
    
    // Create context for storing current state while placing textures in the atlas
    TextureFitterContext* context = malloc(sizeof(TextureFitterContext));
    
    context->mPlacedTextures = [[NSMutableArray alloc] initWithCapacity:[mTextureList count]];
    context->mScanlineEntries = [[NSMutableArray alloc] initWithCapacity:([mTextureList count] * 2)];

    // Calculate the area of all textures, plus maximum dimension
    
    int area = 0;
    int maxWidth = 0;
    int maxHeight = 0;
        
    for (TextureAtlasEntry* curTextureEntry in mTextureList)
    {
        Texture* curTexture = curTextureEntry->mTexture;
        
        area += ([curTexture GetMaxWidth] * [curTexture GetMaxHeight]);
        
        if ([curTexture GetMaxHeight] >= maxHeight)
        {
            maxHeight = [curTexture GetMaxHeight];
        }
        
        if ([curTexture GetMaxWidth] >= maxWidth)
        {
            maxWidth = [curTexture GetMaxWidth];
        }
    }
    
    // Now let's try and determine a good starting size
        
    // Round width up to next power of two
    int potWidth = RoundUpPOT(maxWidth);
    
    // Round height up to next power of two
    int potHeight = RoundUpPOT(maxHeight);

    while ((potWidth < maxWidth) || (potHeight < maxHeight) || ((potWidth * potHeight) < area))
    {
        if (potWidth < maxWidth)
        {
            potWidth *= 2;
        }
        
        if (potHeight < maxHeight)
        {
            potHeight *= 2;
        }
        
        if ((potWidth * potHeight) < area)
        {
            if (potWidth < potHeight)
            {
                potWidth *= 2;
            }
            else
            {
                potHeight *= 2;
            }
        }
    }
        
    while (![self FitIntoAtlasWithWidth:potWidth height:potHeight context:context])
    {
        [self ReinitContext:context];
        
        if (potWidth < potHeight)
        {
            potWidth *= 2;
        }
        else
        {
            potHeight *= 2;
        }
    }
        
    // Now that all textures have assigned texture atlas information, time to actually create the texture.
    [self CreateGLTexture:context];
    
    [context->mPlacedTextures release];
    [context->mScanlineEntries release];
    free(context);
    
    // Now that the atlas texture has been created, free all texture data that's no longer needed.
    
    for (TextureAtlasEntry* curEntry in mTextureList)
    {
        if (curEntry->mTexture->mParams.mTexDataLifetime == TEX_DATA_DISPOSE)
        {
            [curEntry->mTexture FreeClientData];
        }
    }
}

-(void)CreateGLTexture:(TextureFitterContext*)inContext
{
    glGenTextures(1, &mTextureObject);
    glBindTexture(GL_TEXTURE_2D, mTextureObject);
    
    // Currently, texture atlases are only used for UI.  So hardcoded nearest filtering is fine.
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, mAtlasWidth, mAtlasHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    for (Texture* curTexture in inContext->mPlacedTextures)
    {
        glTexSubImage2D(    GL_TEXTURE_2D, 0, curTexture->mTextureAtlasInfo.mX, curTexture->mTextureAtlasInfo.mY,
                            curTexture->mWidth, curTexture->mHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)curTexture->mTexBytes);
    }
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    NeonGLError();
}

-(void)Bind
{
    NSAssert(mTextureObject != 0, @"There is no OpenGL texture object associated with this texture atlas");
    
    glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, mTextureObject);
}

-(BOOL)AtlasCreated
{
    return (mTextureObject != 0);
}

-(BOOL)FitIntoAtlasWithWidth:(int)width height:(int)height context:(TextureFitterContext*)inContext
{    
    mAtlasWidth = width;
    mAtlasHeight = height;
    
    for (TextureAtlasEntry* curTextureEntry in mTextureList)
    {
        Texture* curTexture = curTextureEntry->mTexture;
        
        if (![self PackTexture:curTexture context:inContext])
        {
            return FALSE;
        }
    }
        
    return TRUE;
}

-(BOOL)PackTexture:(Texture*)inTexture context:(TextureFitterContext*)inContext
{
    for (ScanlineEntry* curEntry in inContext->mScanlineEntries)
    {
        for (Texture* testTexture in curEntry->mTextures)
        {
            // If the texture has its top on the scanline, then 
            int width, height;
            int useX = (testTexture->mTextureAtlasInfo.mX + [testTexture GetMaxWidth]);
            int useY = curEntry->mY;
                        
            // If this is the bottom of the texture, then try left aligning the textures.
            if (testTexture->mTextureAtlasInfo.mY != curEntry->mY)
            {
                useX = testTexture->mTextureAtlasInfo.mX;
            }
            
            [self DetermineRectAtX:useX y:useY width:&width height:&height context:inContext];
            
            if ((width >= [inTexture GetMaxWidth]) && (height >= [inTexture GetMaxHeight]))
            {
                BOOL success = [self PlaceTexture:inTexture x:useX y:useY context:inContext];
                NSAssert(success == TRUE, @"We should have been able to place the texture at this location");
                return TRUE;
            }
        }
    }
    
    ScanlineEntry* lastEntry = (ScanlineEntry*)([inContext->mScanlineEntries lastObject]);
    
    if (lastEntry != NULL)
    {
        // Necessarily, the last entry will be the bottom of a texture.  If we couldn't place a texture on that
        // scanline in the loop above, then we should increment by 1
        if ((mAtlasHeight - (lastEntry->mY + 1)) >= [inTexture GetMaxHeight])
        {
            BOOL success = [self PlaceTexture:inTexture x:0 y:(lastEntry->mY + 1) context:inContext];
            NSAssert(success == TRUE, @"We should have been able to place the texture at this location");
            return TRUE;
        }
        else
        {
            return FALSE;
        }
    }
    else
    {
        BOOL success = [self PlaceTexture:inTexture x:0 y:0 context:inContext];
        NSAssert(success == TRUE, @"We should have been able to place the texture at this location");
        return TRUE;
    }

    return FALSE;
}

-(BOOL)PlaceTexture:(Texture*)inTexture x:(int)inX y:(int)inY context:(TextureFitterContext*)inContext
{
    BOOL success = FALSE;
    
    if (((inX + [inTexture GetMaxWidth]) <= mAtlasWidth) && ((inY + [inTexture GetMaxHeight]) <= mAtlasHeight))
    {
        success = TRUE;
        
        inTexture->mTextureAtlasInfo.mPlaced = TRUE;
        
        inTexture->mTextureAtlasInfo.mX = inX;
        inTexture->mTextureAtlasInfo.mY = inY;
        
        inTexture->mTextureAtlasInfo.mSMin = (float)inX / (float)mAtlasWidth;
        inTexture->mTextureAtlasInfo.mTMin = (float)inY / (float)mAtlasHeight;
        
        inTexture->mTextureAtlasInfo.mSMax = (float)(inX + inTexture->mWidth) / (float)mAtlasWidth;
        inTexture->mTextureAtlasInfo.mTMax = (float)(inY + inTexture->mHeight) / (float)mAtlasHeight;
        
        [inContext->mPlacedTextures addObject:inTexture];
        
        [self AddTexture:inTexture toScanline:inY context:inContext];
        
        NSAssert([inTexture GetMaxHeight] > 1, @"There may be a few small modifications necessary for 1 pixel high textures");
        [self AddTexture:inTexture toScanline:(inY + [inTexture GetMaxHeight]) context:inContext];
        
#if DUMP_SCANLINE_INFO
        [self DumpScanlineInfo:inContext];
#endif
#if DUMP_DEBUG_IMAGE
        [self DumpDebugImage:inContext];
#endif
    }
    
    return success;
}

-(void)AddTexture:(Texture*)inTexture toScanline:(int)inY context:(TextureFitterContext*)inContext
{
    NSAssert(mTextureObject == 0, @"You can't add a texture to a TextureAtlas that has already had CreateAtlas called on it.");
    
    BOOL foundScanline = FALSE;
    
    for (ScanlineEntry* curEntry in inContext->mScanlineEntries)
    {
        if (curEntry->mY == inY)
        {
            // We add the textures in left to right order on this scanline
            
            int addIndex = 0;
            
            for (Texture* curTexture in curEntry->mTextures)
            {
                if (inTexture->mTextureAtlasInfo.mX < curTexture->mTextureAtlasInfo.mX)
                {
                    break;
                }
                
                addIndex++;
            }
            
            [curEntry->mTextures insertObject:inTexture atIndex:addIndex];
            foundScanline = TRUE;
            break;
        }
    }
    
    if (!foundScanline)
    {
        ScanlineEntry* newEntry = [ScanlineEntry alloc];
        
        newEntry->mY = inY;
        newEntry->mTextures = [[NSMutableArray alloc] initWithCapacity:0];
        [newEntry->mTextures addObject:inTexture];
        
        [self AddScanline:newEntry context:inContext];
        [newEntry release];
    }
}

-(void)AddScanline:(ScanlineEntry*)inScanline context:(TextureFitterContext*)inContext
{
    int addIndex = 0;
    
    for (ScanlineEntry* curScanline in inContext->mScanlineEntries)
    {
        if (curScanline->mY == inScanline->mY)
        {
            NSAssert(FALSE, @"We should have checked to see if the scanline existed earlier (in the calling function most likely)");
        }
        else if (curScanline->mY > inScanline->mY)
        {
            break;
        }
        
        addIndex++;
    }
    
    [inContext->mScanlineEntries insertObject:inScanline atIndex:addIndex];
}

-(void)DetermineRectAtX:(int)inX y:(int)inY width:(int*)outWidth height:(int*)outHeight context:(TextureFitterContext*)inContext
{
    int heightRemaining = mAtlasHeight - inY;
    int widthRemaining = mAtlasWidth - inX;
    
    for (Texture* curTexture in inContext->mPlacedTextures)
    {
        // Determine if a placed texture intersects with rays shooting to the right and down from <inX, inY>
        
        // 1) Check if Y-Span of the texture interesects the x-ray shooting to the right, and if the texture is to the right of inX
        
        if (curTexture->mTextureAtlasInfo.mX >= inX)
        {
            if ((inY >= curTexture->mTextureAtlasInfo.mY) && (inY < (curTexture->mTextureAtlasInfo.mY + [curTexture GetMaxHeight])))
            {
                int width = curTexture->mTextureAtlasInfo.mX - inX;
                
                if ((width < widthRemaining) || (width < widthRemaining))
                {
                    widthRemaining = width;
                }
            }
        }
        
        // 2) Check if X-Span of the texture interesects the y-ray shooting downwards, and if the texture is below inY
        
        if (curTexture->mTextureAtlasInfo.mY >= inY)
        {
            if ((inX >= curTexture->mTextureAtlasInfo.mX) && (inX < (curTexture->mTextureAtlasInfo.mX + [curTexture GetMaxWidth])))
            {
                int height = curTexture->mTextureAtlasInfo.mY - inY;
                
                if ((heightRemaining == UNLIMITED_HEIGHT) || (height < heightRemaining))
                {
                    heightRemaining = height;
                }
            }
        }
        
        // If either dimension is zero, then there is no room at this location
        if ((widthRemaining == 0) || (heightRemaining == 0))
        {
            break;
        }
    }
    
    *outWidth = widthRemaining;
    *outHeight = heightRemaining;
}

-(void)ReinitContext:(TextureFitterContext*)context
{
    [context->mPlacedTextures removeAllObjects];
    [context->mScanlineEntries removeAllObjects];
}

-(void)UpdateTexture:(Texture*)inTexture
{
    NSAssert(mTextureObject != 0, @"Can't call UpdateTexture if we haven't created the texture object yet.");
    NSAssert( (inTexture->mWidth <= [inTexture GetMaxWidth]) && (inTexture->mHeight <= [inTexture GetMaxHeight]), @"Trying to add a texture bigger than the max size specified");

    glBindTexture(GL_TEXTURE_2D, mTextureObject);
    glTexSubImage2D(GL_TEXTURE_2D, 0, inTexture->mTextureAtlasInfo.mX, inTexture->mTextureAtlasInfo.mY,
                            inTexture->mWidth, inTexture->mHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)inTexture->mTexBytes);
                            
    
    inTexture->mTextureAtlasInfo.mSMax = (float)(inTexture->mTextureAtlasInfo.mX + inTexture->mWidth) / (float)mAtlasWidth;
    inTexture->mTextureAtlasInfo.mTMax = (float)(inTexture->mTextureAtlasInfo.mY + inTexture->mHeight) / (float)mAtlasHeight;
}

-(void)DumpTextureNames
{
    for (TextureAtlasEntry* curTexture in mTextureList)
    {
        printf("%s, width %d, height %d\n", [curTexture->mTexture->mDebugName UTF8String], [curTexture->mTexture GetMaxWidth], [curTexture->mTexture GetMaxHeight]);
    }
}

-(void)DumpScanlineInfo:(TextureFitterContext*)inContext
{
    for (ScanlineEntry* curEntry in inContext->mScanlineEntries)
    {
        printf("Scanline %d:\n", curEntry->mY);
        
        for (Texture* curTexture in curEntry->mTextures)
        {
            printf("\tTexture %s %s, x: %d\n",  [curTexture->mDebugName UTF8String], (curTexture->mTextureAtlasInfo.mY == curEntry->mY) ? "TOP" : "BOTTOM",
                                                curTexture->mTextureAtlasInfo.mX  );
        }
    }
}

-(void)DumpDebugImage:(TextureFitterContext*)inContext
{
    unsigned char* buffer = malloc(mAtlasWidth * mAtlasHeight * 4);
    
    // Init to white background
    memset(buffer, 0xFF, mAtlasWidth * mAtlasHeight * 4);
    
    TextureAtlasParams atlasParams;
    [TextureAtlas InitDefaultParams:&atlasParams];
    
    TextureAtlas* dummyAtlas = [[TextureAtlas alloc] InitWithParams:&atlasParams];
    
    for (Texture* curTexture in inContext->mPlacedTextures)
    {
        // Rasterize each texture individually
        
        TextTextureParams textTextureParams;
        
        [TextTextureBuilder InitDefaultParams:&textTextureParams];
        
        textTextureParams.mFontName = [NSString stringWithString:@"Andale_Mono.ttf"];
        textTextureParams.mColor = 0xFF;
        textTextureParams.mString = curTexture->mDebugName;
        textTextureParams.mTextureAtlas = dummyAtlas;
        textTextureParams.mPointSize = 9;
                
        Texture* textureNameTexture = [[TextTextureBuilder GetInstance] GenerateTextureWithParams:&textTextureParams];
        
        // Rasterize a block indicating the position of the texture in the atlas
        for (int y = curTexture->mTextureAtlasInfo.mY; y < (curTexture->mTextureAtlasInfo.mY + [curTexture GetMaxHeight]); y++)
        {
            for (int x = curTexture->mTextureAtlasInfo.mX; x < (curTexture->mTextureAtlasInfo.mX + [curTexture GetMaxWidth]); x++)
            {
                unsigned char* writeBase = &buffer[(x + (y * mAtlasWidth)) * 4];
                
                if  ((x == curTexture->mTextureAtlasInfo.mX) || (y == curTexture->mTextureAtlasInfo.mY) || 
                    (x == (curTexture->mTextureAtlasInfo.mX + [curTexture GetMaxWidth] - 1)) ||
                    (y == (curTexture->mTextureAtlasInfo.mY + [curTexture GetMaxHeight] - 1) ))
                {
                    writeBase[0] = 0xFF;
                    writeBase[1] = 0x00;
                    writeBase[2] = 0x00;
                }
                else
                {
                    writeBase[0] = 0xA0;
                    writeBase[1] = 0xA0;
                    writeBase[2] = 0xA0;
                }
            }
        }
        
        // Rasterize the text indicating the texture name
        
        int startX = 0;
        int startY = 0;
        
        if (textureNameTexture->mWidth < [curTexture GetMaxWidth])
        {
            startX = ([curTexture GetMaxWidth] - textureNameTexture->mWidth) / 2;
        }
        
        if (textureNameTexture->mHeight < [curTexture GetMaxHeight])
        {
            startY = ([curTexture GetMaxHeight] - textureNameTexture->mHeight) / 2;
        }
        
        int maxX = min([curTexture GetMaxWidth], textureNameTexture->mWidth);
        int maxY = min([curTexture GetMaxHeight], textureNameTexture->mHeight);
        
        for (int y = 0; y < maxY; y++)
        {
            for (int x = 0; x < maxX; x++)
            {
                int useX = curTexture->mTextureAtlasInfo.mX + startX + x;
                int useY = curTexture->mTextureAtlasInfo.mY + startY + y;
                
                unsigned char* writeBase = &buffer[(useX + (useY * mAtlasWidth)) * 4];
                unsigned char* readBase = &(((unsigned char*)(textureNameTexture->mTexBytes))[(x + (y * [textureNameTexture GetMaxWidth])) * 4]);
                
                // Alpha blend the text onto the debug texture (emulate OpenGL GL_SRC_ALPHA/GL_ONE_MINUS_SRC_ALPHA blend mode)
                float srcR = readBase[0] / 255.0f;
                float srcG = readBase[1] / 255.0f;
                float srcB = readBase[2] / 255.0f;
                float srcA = readBase[3] / 255.0f;
                
                float destR = writeBase[0] / 255.0f;
                float destG = writeBase[1] / 255.0f;
                float destB = writeBase[2] / 255.0f;
                float destA = writeBase[3] / 255.0f;
                
                writeBase[0] = (unsigned char)(((srcR * srcA) + (destR * (1.0f - srcA))) * 255.0f);
                writeBase[1] = (unsigned char)(((srcG * srcA) + (destG * (1.0f - srcA))) * 255.0f);
                writeBase[2] = (unsigned char)(((srcB * srcA) + (destB * (1.0f - srcA))) * 255.0f);
                writeBase[3] = (unsigned char)(((srcA * srcA) + (destA * (1.0f - srcA))) * 255.0f);
            }
        }
    }
    
    WritePNG(buffer, [NSString stringWithFormat:@"%d.png", [inContext->mPlacedTextures count]], mAtlasWidth, mAtlasHeight);
    
    free(buffer);
    [dummyAtlas release];
}

@end