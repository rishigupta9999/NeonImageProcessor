//
//  TextTextureBuilder.m
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "TextTextureBuilder.h"
#import "ResourceManager.h"

#import "NeonMath.h"

#import FT_STROKER_H
#import FT_BITMAP_H

static TextTextureBuilder* sInstance = NULL;

#define FONT_RESOURCE_HANDLE_CAPACITY   (3)
#define GLYPH_SPANS_INITIAL_CAPACITY    (256) 
#define INITIAL_LINE_WIDTH_CAPACITY     (5)
#define TEXT_TEXTURE_PARAMS_SIZE        (76)    // Update this as new fields are added to the parameter structure

// 512K cache makes sense for iPhone 3G, we may want to
// not have a cache at all for release builds since we won't have
// debug text.  Worry about this later.
#define CACHE_EVICT_BEGIN_WATERMARK     (2048 * 1024)
#define CACHE_EVICT_END_WATERMARK       (1536 * 1024)

typedef struct
{
    u8* mTexBytes;
    int mHeight;
    int mWidth;
    int mAdvanceWidth;
    int mLeftOffset;
    int mHorizBearingY;
    int mLine;
    char mCharacter;
} GlyphTexture;

@implementation FontNode
@end

@implementation GlyphSpan
@end

@implementation TextTextureBuilderCacheEntry
@end

static void
RasterCallback(const int y,
               const int count,
               const FT_Span * const spans,
               void * const user) 
{
    NSMutableArray* array = user;

    for (int i = 0; i < count; i++)
    {
        GlyphSpan* newSpan = [GlyphSpan alloc];
        
        newSpan->x = spans[i].x;
        newSpan->y = y;
        newSpan->width = spans[i].len;
        newSpan->coverage = spans[i].coverage;
        
        [array addObject:newSpan];
        [newSpan release];
    }
}

@implementation TextTextureBuilder

+(void)CreateInstance
{
    NSAssert(sInstance == NULL, @"There is already an instance of the TextTextureBuilder");
    
    sInstance = [TextTextureBuilder alloc];
    [sInstance Init];
}

+(void)DestroyInstance
{
    NSAssert(sInstance != NULL, @"There is no instance of the TextTextureBuilder");
    
    [sInstance release];
}

+(TextTextureBuilder*)GetInstance
{
    return sInstance;
}

-(TextTextureBuilder*)Init
{
    FT_Error error;
    
    error = FT_Init_FreeType(&mLibrary);
    NSAssert(error == 0, @"Error initializing freetype");
    
    mFontNodes = [[NSMutableArray alloc] initWithCapacity:FONT_RESOURCE_HANDLE_CAPACITY];
    mOutlineSpans = [[NSMutableArray alloc] initWithCapacity:GLYPH_SPANS_INITIAL_CAPACITY];
    mInsideSpans = [[NSMutableArray alloc] initWithCapacity:GLYPH_SPANS_INITIAL_CAPACITY];
    
    mTextureCache = [[NSMutableArray alloc] initWithCapacity:0];
    
    return self;
}

-(void)dealloc
{
    [mFontNodes release];
    [mOutlineSpans release];
    [mInsideSpans release];
    [mTextureCache release];
    
    [super dealloc];
}

+(void)InitDefaultParams:(TextTextureParams*)outParams
{
    outParams->mFontName = [NSString stringWithString:@"Andale Mono.ttf"];
    outParams->mFontData = NULL;
    outParams->mPointSize = 24;
    outParams->mString = NULL;
    outParams->mColor = 0xFFFFFFFF;
    outParams->mStrokeColor = 0;
    outParams->mWidth = 0;
    
    outParams->mLeadWidth = 0;
    outParams->mLeadHeight = 0;
    outParams->mTrailWidth = 0;
    outParams->mTrailHeight = 0;
    
    outParams->mStrokeSize = 0;
    outParams->mPremultipliedAlpha = FALSE;
    
    outParams->mTextureAtlas = NULL;
    outParams->mTexture = NULL;
}

-(Texture*)GenerateTextureWithFont:(NSString*)inFontName PointSize:(u32)inPointSize String:(NSString*)inString Color:(u32)inColor
{
    return [self GenerateTextureWithFont:inFontName PointSize:inPointSize String:inString Color:inColor Width:0];
}

-(Texture*)GenerateTextureWithFont:(NSString*)inFontName PointSize:(u32)inPointSize String:(NSString*)inString Color:(u32)inColor Width:(u32)inWidth;
{
    TextTextureParams params;
    
    [TextTextureBuilder InitDefaultParams:&params];
        
    params.mFontName = inFontName;
    params.mPointSize = inPointSize;
    params.mString = inString;
    params.mColor = inColor;
    params.mWidth = inWidth;
    
    return [self GenerateTextureWithParams:&params];
}

-(Texture*)GenerateTextureWithParams:(TextTextureParams*)inParams
{
#if USE_TEXT_CACHE
    Texture* texture = [self LookupInCache:inParams];
    
    if (texture != NULL)
    {
        [texture retain];
        [texture autorelease];
        
        return texture;
    }
#endif
    
    NSString* fontName = inParams->mFontName;
    u32 pointSize = inParams->mPointSize;
    NSString* string = inParams->mString;
    u32 stringWidth = inParams->mWidth;
    u32 color = inParams->mColor;
    u32 strokeColor = inParams->mStrokeColor;
    u32 leadHeight = inParams->mLeadHeight;
    u32 leadWidth = inParams->mLeadWidth;
    u32 trailHeight = inParams->mTrailHeight;
    u32 trailWidth = inParams->mTrailWidth;
    u32 strokeSize = inParams->mStrokeSize;
    
    NSNumber* resourceHandle = NULL;
    FontNode* curNode = NULL;
    NSData* fontData = NULL;
    FT_Error error = 0;
    BOOL createFontNode = FALSE;
    BOOL fontLoaded = FALSE;
        
    NSAssert( ((inParams->mFontName != NULL) ^ (inParams->mFontData != NULL)), @"*EITHER* a font name or NSData for the font should be specified.  Not both." );
    
    if (inParams->mFontData == NULL)
    {
        ResourceNode* resourceNode = [[ResourceManager GetInstance] FindResourceWithName:fontName];
        
        if (resourceNode == NULL)
        {
            resourceHandle = [[ResourceManager GetInstance] LoadAssetWithName:fontName];
            
            createFontNode = TRUE;
            fontLoaded = TRUE;
        }
        else
        {
            resourceHandle = resourceNode->mHandle;
            
            createFontNode = TRUE;
            
            for (int i = 0; i < [mFontNodes count]; i++)
            {
                curNode = [mFontNodes objectAtIndex:i];
                
                if (curNode->mResourceHandle == resourceHandle)
                {
                    createFontNode = FALSE;
                    break;
                }
            }
        }
    }
    else
    {
        createFontNode = TRUE;
    }
        
    if (createFontNode)
    {
        if (inParams->mFontData == NULL)
        {
            fontData = [[ResourceManager GetInstance] GetDataForHandle:resourceHandle];
        }
        else
        {
            fontData = inParams->mFontData;
        }
        
        curNode = [FontNode alloc];
        curNode->mResourceHandle = resourceHandle;
        
        error = FT_New_Memory_Face( mLibrary, (unsigned char*)[fontData bytes], [fontData length], 0, &curNode->mFace);
        
        if (error != 0)
        {
            [curNode release];
            
            if (fontLoaded)
            {
                [[ResourceManager GetInstance] UnloadAssetWithHandle:resourceHandle];
            }
        }
        else
        {
            [mFontNodes addObject:curNode];
        }
    }
    
    // At this point, curNode->mFace should contain our font face.  This is all we need to render glyphs of a certain font.
    
    error = FT_Set_Char_Size(   curNode->mFace,     /* handle to face object           */
                                0,                  /* char_width in 1/64th of points  */
                                pointSize * 64,   /* char_height in 1/64th of points */
                                72,                 /* horizontal device resolution    */
                                72 );               /* vertical device resolution      */
    
    NSAssert(error == 0, @"Error setting character size.  Double check your arguments here");
    
    Texture* newTexture = NULL;
    
    if (inParams->mTexture == NULL)
    {
        newTexture = [Texture alloc];
        [newTexture Init];
        
        newTexture->mParams.mTextureAtlas = inParams->mTextureAtlas;
    }
    else
    {
        newTexture = inParams->mTexture;
        [newTexture FreeClientData];
    }
    
    // We'll create a buffer for each character - and then concatenate them into one texture afterwards
    
    const char* cString = [string UTF8String];
    int stringLength = strlen(cString);
    
    GlyphTexture* textureArray = malloc(sizeof(GlyphTexture) * stringLength);
    memset(textureArray, 0, sizeof(GlyphTexture) * stringLength);
    
    u32 texWidth = 0;
    u32 texHeight = 0;
    int maxY = 0;
    int minY = 0;
    int curLine = 0;
	
	int firstCharXOffset = 0;
    
    NSMutableArray* lineWidth = [[NSMutableArray alloc] initWithCapacity:INITIAL_LINE_WIDTH_CAPACITY];
    int curLineWidth = 0;
    
    for (int i = 0; i < stringLength; i++)
    {
        // Render one character.
        error = FT_Load_Char( curNode->mFace, cString[i], FT_LOAD_DEFAULT );
        NSAssert(error == 0, @"Could not load a glyph.");
        
        FT_GlyphSlot glyphSlot = curNode->mFace->glyph;
        
        if (strokeSize == 0)
        {
            FT_Render_Glyph(glyphSlot, FT_RENDER_MODE_NORMAL);
        }
        else
        {
            NSAssert(glyphSlot->format == FT_GLYPH_FORMAT_OUTLINE, @"Can't generate a stroke for a font with no outlines.");
            
            FT_Stroker stroker;
            FT_Stroker_New(mLibrary, &stroker);
            
            FT_Stroker_Set(stroker,
                           (int)(strokeSize * 64),
                           FT_STROKER_LINECAP_ROUND,
                           FT_STROKER_LINEJOIN_ROUND,
                           0);

            FT_Glyph glyph;
            
            FT_Raster_Params params;
            memset(&params, 0, sizeof(params));
            
            params.flags = FT_RASTER_FLAG_AA | FT_RASTER_FLAG_DIRECT;
            params.gray_spans = RasterCallback;
            params.user = mInsideSpans;
            
            FT_Error err = FT_Outline_Render(mLibrary, &curNode->mFace->glyph->outline, &params);
            
            if (FT_Get_Glyph(glyphSlot, &glyph) == 0)
            {
                FT_Glyph_StrokeBorder(&glyph, stroker, 0, 1);
                
                if (glyph->format == FT_GLYPH_FORMAT_OUTLINE)
                {
                    // Render the outline spans to the span list
                    FT_Outline* outline = &((FT_OutlineGlyph)(glyph))->outline;
                    
                    memset(&params, 0, sizeof(params));
                    
                    params.flags = FT_RASTER_FLAG_AA | FT_RASTER_FLAG_DIRECT;
                    params.gray_spans = RasterCallback;
                    params.user = mOutlineSpans;

                    err = FT_Outline_Render(mLibrary, outline, &params); 
                    NSAssert(err == 0, @"Error rendering outline");
                    
                    FT_Stroker_Done(stroker);
                    FT_Done_Glyph(glyph);
                    
                    Color insideColor, outsideColor;
                    
                    SetColorFromU32(&insideColor, color);
                    SetColorFromU32(&outsideColor, strokeColor);
                    
                    [self GenerateStrokeBitmap:glyphSlot insideColor:&insideColor outsideColor:&outsideColor];
                }
                else
                {
                    NSAssert(FALSE, @"Glyph isn't outline format for some reason.  Make sure you're using a TrueType font or other vector font.");
                }

            }
            else
            {
                NSAssert(FALSE, @"Couldn't get glyph for some reason.");
            }
            
        }

        int height = glyphSlot->bitmap.rows;
        int width = glyphSlot->bitmap.width;
        
        if ((height != 0) && (width != 0))
        {
            u32 texelSize = (strokeSize == 0) ? 1 : sizeof(u32);
            
            textureArray[i].mTexBytes = malloc(texelSize * height * width);
            memcpy(textureArray[i].mTexBytes, glyphSlot->bitmap.buffer, texelSize * height * width);
            
            if (strokeSize != 0)
            {
                free(glyphSlot->bitmap.buffer);
            }
        }
        
        textureArray[i].mHeight = height;
        textureArray[i].mWidth = width;
        
        textureArray[i].mLeftOffset = glyphSlot->bitmap_left;
        textureArray[i].mHorizBearingY = glyphSlot->metrics.horiBearingY >> 6;
        
        textureArray[i].mAdvanceWidth = (glyphSlot->advance.x >> 6) + (2 * strokeSize);
        
        textureArray[i].mCharacter = cString[i];
		
		if (i == 0)
		{
			if (glyphSlot->bitmap_left < 0)
			{
				texWidth += (-glyphSlot->bitmap_left);
				firstCharXOffset = -glyphSlot->bitmap_left;
			}
		}
        
        if ((stringWidth == 0) || ((curLineWidth + textureArray[i].mAdvanceWidth) <= stringWidth))
        {
            curLineWidth += textureArray[i].mAdvanceWidth;
        }
        else
        {
            // Search backwards for a whitespace character
            int searchIndex = 0;
            BOOL fail = FALSE;
            
            for (searchIndex = (i - 1); searchIndex >= 0; searchIndex--)
            {
                char val = cString[searchIndex];
                
                if (textureArray[searchIndex].mLine != curLine)
                {
                    fail = TRUE;
                    break;
                }

                if ((val == ' ') || (val == '\n') || (val == '\r') || (val == '\t'))
                {
                    // Don't move the whitespace down to the next line
                    searchIndex++;
                    break;
                }
            }
            
            int lastCharIndex = i - 1;
            
            // No whitespace, we'll just wrap by the character instead of whole word - we have no choice
            if ((searchIndex != 0) && (!fail))
            {
                for (int curIndex = searchIndex; curIndex < i; curIndex++)
                {
                    textureArray[curIndex].mLine++;
                }
                
                lastCharIndex = searchIndex - 1;
            }

            // Recalculate the previous line's width since we removed some characters from it.
            
            curLineWidth = 0;
            
            for (int curIndex = (i - 1); curIndex != 0; curIndex--)
            {
                if (textureArray[curIndex].mLine == curLine)
                {
                    curLineWidth += textureArray[curIndex].mAdvanceWidth;
                }
                
                if (textureArray[curIndex].mLine < curLine)
                {
                    break;
                }
            }
            
            // The previous character might have an advance width smaller than the actual width.  Bump up the
            // line width appropriately.  This only matters for the last character in a line so that we allocate
            // a texture wide enough.
            
            int maxGlyphWidth = max(textureArray[lastCharIndex].mAdvanceWidth, textureArray[lastCharIndex].mWidth);
            int delta = maxGlyphWidth - textureArray[lastCharIndex].mAdvanceWidth;
            
            curLineWidth += delta;
            
            [lineWidth addObject:[NSNumber numberWithUnsignedInt:curLineWidth]];
            curLine++;
            
            curLineWidth = 0;
            
            // Since we shifted characters onto the next line, we have to recalculate its starting width.
            for (int curIndex = 0; curIndex <= i; curIndex++)
            {
                if (textureArray[curIndex].mLine == curLine)
                {
                    curLineWidth += textureArray[curIndex].mAdvanceWidth;
                }
            }
            
            curLineWidth += textureArray[i].mAdvanceWidth;
            minY = 0;
        }
        
        textureArray[i].mLine = curLine;
        
        if (curLine == 0)
        {
            maxY = max(maxY, glyphSlot->metrics.horiBearingY >> 6);
        }
        
        minY = min(minY, (glyphSlot->metrics.horiBearingY >> 6) - height);
    }
    
    int maxGlyphWidth = max(textureArray[stringLength - 1].mAdvanceWidth, textureArray[stringLength - 1].mWidth);
    int delta = maxGlyphWidth - textureArray[stringLength - 1].mAdvanceWidth;

    curLineWidth += delta;

    [lineWidth addObject:[NSNumber numberWithUnsignedInt:curLineWidth]];
    
    int numLines = [lineWidth count];

    for (NSNumber* curNumber in lineWidth)
    {
        texWidth = max([curNumber unsignedIntValue], texWidth);
    }
    
    texWidth += (leadWidth + trailWidth);
    
    [lineWidth release];
    
    int lineHeight = curNode->mFace->size->metrics.height >> 6;
    
    texHeight = (numLines * lineHeight) + max((maxY - lineHeight), 0) - min(0, minY);
    texHeight += (leadHeight + trailHeight);
    
    u32 paddedWidth = 0;
    u32 paddedHeight = 0;
    
    if (inParams->mTextureAtlas == NULL)
    {
        [Texture RoundToValidDimensionsWidth:texWidth Height:texHeight ValidWidth:&paddedWidth ValidHeight:&paddedHeight];
    }
    else
    {
        // If we're using a texture atlas, then there are no power-of-two size restrictions on the subtextures.  Don't
        // waste memory with the padding.
        paddedWidth = texWidth;
        paddedHeight = texHeight;
    }
    
    // Okay, now create a texture big enough to hold all the glyphs side by side.
  
    newTexture->mTexBytes = malloc(sizeof(u32) * paddedWidth * paddedHeight);
    memset(newTexture->mTexBytes, 0, sizeof(u32) * paddedWidth * paddedHeight);
    
    inParams->mStartX = texWidth - 1;
    inParams->mEndX = 0;
    inParams->mStartY = texHeight - 1;
    inParams->mEndY = 0;
    
    int baseX = 0;
    int lastLine = 0;
    
    for (int i = 0; i < stringLength; i++)
    {
        GlyphTexture* curGlyph = &textureArray[i];
        
        if (curGlyph->mLine != lastLine)
        {
            lastLine = curGlyph->mLine;
            baseX = 0;
        }
        
        u32 useColor = (strokeSize == 0) ? color : strokeColor;
                
        for (int y = 0; y < curGlyph->mHeight; y++)
        {
            for (int x = 0; x < curGlyph->mWidth; x++)
            {
                // Number of lines from the top to start writing
                int writeYOffset = maxY - curGlyph->mHorizBearingY;
            
                int readIndex = x + (y * curGlyph->mWidth);
                
                if (strokeSize != 0)
                {
                    readIndex *= sizeof(u32);
                }
                
                int writeX = baseX + leadWidth + x + firstCharXOffset + curGlyph->mLeftOffset;
                int writeY = y + writeYOffset + leadHeight + (curGlyph->mLine * lineHeight);
                int writeIndex = writeX + (writeY * paddedWidth);
                
                // Only render something is the alpha is greater than 0
                BOOL renderedTexel = strokeSize == 0 ?
                                     (curGlyph->mTexBytes[readIndex] & 0xFF) > 0 :
                                     *((u32*)&curGlyph->mTexBytes[readIndex]) != 0;
                
                if (renderedTexel)
                {
                    u32 texVal = (useColor & 0xFFFFFF00) | curGlyph->mTexBytes[readIndex];
                    texVal = CFSwapInt32BigToHost(texVal);
                    
                    if (strokeSize != 0)
                    {
                        u8 r = curGlyph->mTexBytes[readIndex];
                        u8 g = curGlyph->mTexBytes[readIndex + 1];
                        u8 b = curGlyph->mTexBytes[readIndex + 2];
                        u8 a = curGlyph->mTexBytes[readIndex + 3];
                        
                        if (inParams->mPremultipliedAlpha)
                        {
                            float rf = (float)r / 255.0f;
                            float gf = (float)g / 255.0f;
                            float bf = (float)b / 255.0f;
                            float af = (float)a / 255.0f;
                            
                            r = (u8)((rf * af) * 255.0f);
                            g = (u8)((gf * af) * 255.0f);
                            b = (u8)((bf * af) * 255.0f);
                        }
                        
                        texVal =    (r << 24) | (g << 16) | (b << 8) | a;                                                                        
                        texVal = CFSwapInt32BigToHost(texVal);
                    }
                    else if (inParams->mPremultipliedAlpha)
                    {
                        u8 r = (texVal & 0xFF);
                        u8 g = (texVal >> 8) & 0xFF;
                        u8 b = (texVal >> 16) & 0xFF;
                        u8 a = (texVal >> 24) & 0xFF;
                        
                        float rf = (float)r / 255.0f;
                        float gf = (float)g / 255.0f;
                        float bf = (float)b / 255.0f;
                        float af = (float)a / 255.0f;

                        r = (u8)((rf * af) * 255.0f);
                        g = (u8)((gf * af) * 255.0f);
                        b = (u8)((bf * af) * 255.0f);
                        
                        texVal =    (r << 24) | (g << 16) | (b << 8) | a;                                                                        
                        texVal = CFSwapInt32BigToHost(texVal);
                    }
                    
                    // Save off the bounds that we rendered texels to.  Useful for centering and positioning text without regard for texture
                    // padding (eg: power-of-two padding)
                    
                    if (writeX < inParams->mStartX)
                    {
                        inParams->mStartX = writeX;
                    }
                    
                    if (writeX > inParams->mEndX)
                    {
                        inParams->mEndX = writeX;
                    }
                    
                    if (writeY < inParams->mStartY)
                    {
                        inParams->mStartY = writeY;
                    }
                    
                    if (writeY > inParams->mEndY)
                    {
                        inParams->mEndY = writeY;
                    }

                    NSAssert(writeIndex < (paddedWidth * paddedHeight), @"About to write glyph out of the allocated block of memory.");

                    newTexture->mTexBytes[writeIndex] = texVal;
                }
            }
        }
        
        if (strokeSize != 0)
        {
//            WritePNG(curGlyph->mTexBytes, @"Test.PNG", curGlyph->mWidth, curGlyph->mHeight);
        }
        
		free(textureArray[i].mTexBytes);

        baseX += curGlyph->mAdvanceWidth;
    }

	free(textureArray);
    newTexture->mWidth = paddedWidth;
    newTexture->mHeight = paddedHeight;
    
    [newTexture CreateGLTexture];
    
    newTexture->mWidth = texWidth;
    newTexture->mHeight = texHeight;
    
    newTexture->mDebugName = inParams->mString;
    [newTexture->mDebugName retain];
    
    newTexture->mPremultipliedAlpha = inParams->mPremultipliedAlpha;
	
    if (inParams->mTexture == NULL)
    {
        [newTexture autorelease];
    }
    
#if USE_TEXT_CACHE
    // We only specify mFontData in the Neon21ImageProcessor.  It's not worth supporting this case.
    if (inParams->mFontData == NULL)
    {
        [self AddToCache:newTexture withParams:inParams];
    }
#endif
	
    return newTexture;
}

-(void)GenerateStrokeBitmap:(FT_GlyphSlot)inSlot insideColor:(Color*)inInsideColor outsideColor:(Color*)inOutsideColor
{
    NSAssert(inSlot->bitmap.buffer == NULL, @"Bitmap was already allocated, how did this happen?");
    
    FT_Bitmap* bitmap = &inSlot->bitmap;

    // For whitespace characters, don't do anything
    if ([mOutlineSpans count] == 0)
    {
        bitmap->rows = 0;
        bitmap->width = 0;
        bitmap->buffer = NULL;
        return;
    }
    
    u32 insideColor = GetRGBAU32(inInsideColor);
    u32 outsideColor = GetRGBAU32(inOutsideColor);
    
    // Render outside spans
    Rect2D rect;
    
    GlyphSpan* first = [mOutlineSpans objectAtIndex:0];
    
    rect.mXMin = first->x;
    rect.mYMin = first->y;
    rect.mXMax = first->x + first->width - 1;
    rect.mYMax = first->y;
    
    for (GlyphSpan* curSpan in mOutlineSpans)
    {
        Rect2D curRect;
        
        curRect.mXMin = curSpan->x;
        curRect.mYMin = curSpan->y;
        curRect.mXMax = curSpan->x + curSpan->width;
        curRect.mYMax = curSpan->y;
        
        NeonUnionRect(&rect, &curRect);
    }
        
    bitmap->rows = rect.mYMax - rect.mYMin + 1;
    bitmap->width = rect.mXMax - rect.mXMin + 1;
    
    bitmap->buffer = (unsigned char*)malloc(bitmap->rows * bitmap->width * sizeof(u32));
    
    memset(bitmap->buffer, 0, bitmap->rows * bitmap->width * sizeof(u32));
        
    for (GlyphSpan* curSpan in mOutlineSpans)
    {
        for (int x = 0; x < curSpan->width; x++)
        {
            int writeOffset = (bitmap->rows - 1 - (curSpan->y - rect.mYMin)) * bitmap->width + (curSpan->x - rect.mXMin + x);
            writeOffset *= sizeof(u32);
            
            NSAssert(((writeOffset >= 0) && (writeOffset < (bitmap->rows * bitmap->width * sizeof(u32)))), @"Attempted write out of range");
            
            bitmap->buffer[writeOffset] = (outsideColor & 0xFF000000) >> 24;
            bitmap->buffer[writeOffset + 1] = (outsideColor & 0x00FF0000) >> 16;
            bitmap->buffer[writeOffset + 2] = (outsideColor & 0x0000FF00) >> 8;
            bitmap->buffer[writeOffset + 3] = curSpan->coverage; 
        }
    }
    
    [mOutlineSpans removeAllObjects];
        
    // Alpha blend inside spans on top
    NSAssert([mInsideSpans count] > 0, @"No inside spans, how is this possible?");
    
    first = [mInsideSpans objectAtIndex:0];
    
    for (GlyphSpan* curSpan in mInsideSpans)
    {
        for (int x = 0; x < curSpan->width; x++)
        {
            int writeOffset = (bitmap->rows - 1 - (curSpan->y - rect.mYMin)) * bitmap->width + (curSpan->x - rect.mXMin + x);
            writeOffset *= sizeof(u32);
            
            NSAssert(((writeOffset >= 0) && (writeOffset < (bitmap->rows * bitmap->width * sizeof(u32)))), @"Attempted write out of range");
            
            if (insideColor == 0)
            {
                bitmap->buffer[writeOffset] = (outsideColor & 0xFF000000) >> 24;
                bitmap->buffer[writeOffset + 1] = (outsideColor & 0x00FF0000) >> 16;
                bitmap->buffer[writeOffset + 2] = (outsideColor & 0x0000FF00) >> 8;
                bitmap->buffer[writeOffset + 3] = max(0, bitmap->buffer[writeOffset + 3] - curSpan->coverage); 
            }
            else
            {
                float destRed = (float)(bitmap->buffer[writeOffset] / 255.0);
                float destGreen = (float)(bitmap->buffer[writeOffset + 1] / 255.0);
                float destBlue = (float)(bitmap->buffer[writeOffset + 2] / 255.0);
                //float destAlpha = (float)(bitmap->buffer[writeOffset + 3] / 255.0);
                
                float srcRed = (float)(((insideColor & 0xFF000000) >> 24) / 255.0);
                float srcGreen = (float)(((insideColor & 0x00FF0000) >> 16) / 255.0);
                float srcBlue = (float)(((insideColor & 0x0000FF00) >> 8) / 255.0);
                float srcAlpha = (float)(curSpan->coverage / 255.0);
                
                bitmap->buffer[writeOffset] = 255.0 * ((srcRed * srcAlpha) + (destRed * (1.0 - srcAlpha)));
                bitmap->buffer[writeOffset + 1] = 255.0 * ((srcGreen * srcAlpha) + (destGreen * (1.0 - srcAlpha)));
                bitmap->buffer[writeOffset + 2] = 255.0 * ((srcBlue * srcAlpha) + (destBlue * (1.0 - srcAlpha)));
                bitmap->buffer[writeOffset + 3] = 255.0;
            }
        }
    }
    
    [mInsideSpans removeAllObjects];
}

-(void)AddToCache:(Texture*)inTexture withParams:(TextTextureParams*)inParams
{
    NSAssert(![self LookupInCache:inParams], @"Item is already in cache");
    
    // Don't cache in the case where a caller wants us to load texel data into a pre-existing texture object.
    if (inParams->mTexture)
    {
        return;
    }
    
    mCacheSize += [inTexture GetSizeBytes];
    
    if (mCacheSize > CACHE_EVICT_BEGIN_WATERMARK)
    {
        [self EvictCacheToWatermark];
    }
    
    TextTextureBuilderCacheEntry* newEntry = [TextTextureBuilderCacheEntry alloc];
    
    memcpy(&newEntry->mParams, inParams, sizeof(TextTextureParams));
    [newEntry->mParams.mFontName retain];
    [newEntry->mParams.mString retain];
    
    [inTexture retain];
    
    newEntry->mTexture = inTexture;
    newEntry->mLastUsedTime = CFAbsoluteTimeGetCurrent();
    
    // Add to the top of the list as the most recently used text texture.
    [mTextureCache insertObject:newEntry atIndex:0];
}

-(BOOL)CompareParams:(TextTextureParams*)inLeftParams withParams:(TextTextureParams*)inRightParams
{
    NSAssert(   sizeof(TextTextureParams) == TEXT_TEXTURE_PARAMS_SIZE, 
                @"Fields were modified in the TextTextureParams structure.  We need to modify the comparison below."    );
    
    if ([inLeftParams->mFontName caseInsensitiveCompare:inRightParams->mFontName] != NSOrderedSame)
    {
        return FALSE;
    }
    
    if ([inLeftParams->mString caseInsensitiveCompare:inRightParams->mString] != NSOrderedSame)
    {
        return FALSE;
    }
    
    if (    (inLeftParams->mPointSize != inRightParams->mPointSize) ||
            (inLeftParams->mColor != inRightParams->mColor) ||
            (inLeftParams->mWidth != inRightParams->mWidth) ||
            (inLeftParams->mLeadWidth != inRightParams->mLeadWidth) ||
            (inLeftParams->mLeadHeight != inRightParams->mLeadHeight) ||
            (inLeftParams->mTrailWidth != inRightParams->mTrailWidth) ||
            (inLeftParams->mTrailHeight != inRightParams->mTrailHeight) ||
            (inLeftParams->mStrokeSize != inRightParams->mStrokeSize) ||
            (inLeftParams->mStrokeColor != inRightParams->mStrokeColor) ||
            (inLeftParams->mPremultipliedAlpha != inRightParams->mPremultipliedAlpha) ||
            (inLeftParams->mTextureAtlas != inRightParams->mTextureAtlas)
            //
            // I don't think it's necessary that two entries have the same owning texture.
            // One caller could have specified no owning texture, the other caller could have specified
            // a particular texture that the Text string should be loaded into.  There's no reason that
            // the same texture object can't be used for both as far as I can tell.
            //
            //(inLeftParams->mTexture != inRightParams->mTexture)
            )
    {
        return FALSE;
    }
    
    return TRUE;
}

-(Texture*)LookupInCache:(TextTextureParams*)inParams
{
    for (TextTextureBuilderCacheEntry* curEntry in mTextureCache)
    {
        if ([self CompareParams:inParams withParams:&curEntry->mParams])
        {
            // Copy the output parameters that we cached last time
            inParams->mStartX = curEntry->mParams.mStartX;
            inParams->mStartY = curEntry->mParams.mStartY;
            inParams->mEndX = curEntry->mParams.mEndX;
            inParams->mEndY = curEntry->mParams.mEndY;
            
            // Update the last time this texture was used, it moves to the
            // top of the list as the most recently used texture.
            curEntry->mLastUsedTime = CFAbsoluteTimeGetCurrent();
            
            [mTextureCache removeObject:curEntry];
            [mTextureCache insertObject:curEntry atIndex:0];
            
            return curEntry->mTexture;
        }
    }
    
    return NULL;
}

-(void)EvictCacheToWatermark
{
    while(mCacheSize > CACHE_EVICT_END_WATERMARK)
    {
        TextTextureBuilderCacheEntry* curEntry = [mTextureCache objectAtIndex:0];
        
        [mTextureCache removeObjectAtIndex:0];
        
        mCacheSize -= [curEntry->mTexture GetSizeBytes];
        
        [curEntry->mTexture release];
        [curEntry->mParams.mFontName release];
        [curEntry->mParams.mString release];
        
        [curEntry release];
    }
}

@end