/*
 *  Operation.cpp
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */


#import "Operation.h"
#import "GLHelper.h"

#import "BloomGaussianFilter.h"
#import "KaiserFilter.h"
#import "ResourceManager.h"

#import "TextureManager.h"
#import "PNGTexture.h"

#import "PNGUtilities.h"

#import "ImageProcessorDefines.h"

const char* FONT_PATH_PARAMETER_NAME = "fontPath";
const char* GENERATE_TEXT_STRING_PARAMETER_NAME = "generateTextString";
const char* GENERATE_STINGER_FLAG_NAME = "generateStinger";
const char* GENERATE_RETINA_FLAG_NAME = "-generateRetina";

@implementation Operation

+(Operation*)OperationWithType:(OperationType)inType
{
    Operation* newOp = [Operation alloc];
    
    [newOp Init];
    
    newOp->mType = inType;
    
    return newOp;
}

-(void)Init
{
    mInputFile = NULL;
    mOutputFile = NULL;
    mOutputDirectory = NULL;
    mArguments = NULL;
    
    mType = OPERATION_INVALID;
}

-(void)SetInputFile:(NSString*)inString
{
    mInputFile = inString;
}

-(void)SetOutputFile:(NSString*)inString
{
    mOutputFile = inString;
}

-(void)SetOutputDirectory:(NSString*)inString
{
    mOutputDirectory = inString;
}

-(void)SetArguments:(NSMutableArray*)inArguments
{
    mArguments = inArguments;
}

-(void)SanitizePaths
{
    if (mInputFile != NULL)
    {
        BOOL inputIsDirectory = FALSE;
        [[NSFileManager defaultManager] fileExistsAtPath:mInputFile isDirectory:&inputIsDirectory];
        
        if (inputIsDirectory)
        {
            if (![mInputFile hasSuffix:@"/"])
            {
                mInputFile = [mInputFile stringByAppendingString:@"/"];
            }
        }
    }
    
    if (mOutputFile != NULL)
    {
        BOOL outputIsDirectory = FALSE;
        [[NSFileManager defaultManager] fileExistsAtPath:mOutputFile isDirectory:&outputIsDirectory];
        
        if (outputIsDirectory)
        {
            if (![mOutputFile hasSuffix:@"/"])
            {
                mOutputFile = [mOutputFile stringByAppendingString:@"/"];
            }
        }
    }
    
    if (mOutputDirectory != NULL)
    {
        if (![mOutputDirectory hasSuffix:@"/"])
        {
            mOutputDirectory = [mOutputDirectory stringByAppendingString:@"/"];
        }
    }
}

-(void)Perform
{
    [self SanitizePaths];
    
    switch(mType)
    {
        case OPERATION_BLOOM:
        {
            [self PerformBloom];
            break;
        }
        
        case OPERATION_PREMULTIPLY_ALPHA:
        {
            [self PerformPremultiplyAlpha];
            break;
        }
        
        case OPERATION_GENERATE_MIPMAPS:
        {
            [self PerformGenerateMipmaps];
            break;
        }
        
        case OPERATION_GENERATE_TEXT:
        {
            [self PerformGenerateText];
            break;
        }
    }
}

-(void)PerformBloom
{
	BOOL generateRetina = FALSE;
	
    for (int curArgIndex = 0; curArgIndex < [mArguments count]; curArgIndex++)
    {
		NSString* curArg = [mArguments objectAtIndex:curArgIndex];

        if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_RETINA_FLAG_NAME]] == NSOrderedSame)
        {
            generateRetina = TRUE;
        }
        else
        {
            NSAssert(FALSE, @"Unknown argument provided %@", curArg);
        }
    }

    static const int BORDER_SIZE = 32.0;
    
    NSNumber* texHandle = [[ResourceManager GetInstance] LoadAssetWithPath:mInputFile];
    
    TextureParams texParams;
    
    [Texture InitDefaultParams:&texParams];
    Texture* baseTexture = [[PNGTexture alloc] InitWithData:[[ResourceManager GetInstance] GetDataForHandle:texHandle] textureParams:&texParams];

    BloomGaussianParams params;
    
    [BloomGaussianFilter InitDefaultParams:&params];
    
    if ([[mOutputFile pathExtension] caseInsensitiveCompare:@".PAPNG"])
    {
        params.mPremultipliedAlpha = TRUE;
    }
    
    params.mInputTexture = baseTexture;
    params.mBorder = BORDER_SIZE;
	
	if (generateRetina)
	{
		params.mBorder *= 2;
	}
    
    params.mNumDownsampleLevels = 5;

    BloomGaussianFilter* bloomFilter = [(BloomGaussianFilter*)[BloomGaussianFilter alloc] InitWithParams:&params];
    [bloomFilter SetDrawBaseLayer:FALSE];
    
    [bloomFilter Update:0.0];

    NSMutableArray* textureLayers = [bloomFilter GetTextureLayers];
    Texture* largestTexture = [textureLayers objectAtIndex:([textureLayers count] - 2)];
    [[GLHelper GetInstance] InitializeDrawableWithWidth:largestTexture->mGLWidth height:largestTexture->mGLHeight];
    
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [bloomFilter Draw];
    
    SaveScreenRect(mOutputFile, largestTexture->mWidth, largestTexture->mHeight);
    
    printf("Bloom:\tInput %s\n\tOutput %s\n", [mInputFile UTF8String], [mOutputFile UTF8String]);
}

-(void)PerformPremultiplyAlpha
{
    PNGInfo pngInfo;
    
    BOOL success = ReadPNG(mInputFile, TEX_ADDRESSING_8, &pngInfo);
    
    if (!success)
    {
        printf("\e[1;31m%s isn't a valid PNG, aborting...\e[m\n", [mInputFile UTF8String]);
        return;
    }
    
    for (int y = 0; y < pngInfo.mHeight; y++)
    {
        for (int x = 0; x < pngInfo.mWidth; x++)
        {
            u8* imageBase = &((u8*)pngInfo.mImageData)[(y * pngInfo.mWidth + x) * 4];
            
            u8 r = imageBase[0];
            u8 g = imageBase[1];
            u8 b = imageBase[2];
            u8 a = imageBase[3];
                        
            float rf = (float)r / 255.0;
            float gf = (float)g / 255.0;
            float bf = (float)b / 255.0;
            float af = (float)a / 255.0;
            
            rf *= af;
            gf *= af;
            bf *= af;
            
            imageBase[0] = rf * 255.0;
            imageBase[1] = gf * 255.0;
            imageBase[2] = bf * 255.0;
        }
    }
    
    WritePNG((unsigned char*)pngInfo.mImageData, mOutputFile, pngInfo.mWidth, pngInfo.mHeight);
    
    printf("Premultiply Alpha:\tInput %s\n\t\t\tOutput %s\n", [mInputFile UTF8String], [mOutputFile UTF8String]);
}

-(void)PerformGenerateMipmaps
{    
    BOOL inputIsDirectory = FALSE;
    [[NSFileManager defaultManager] fileExistsAtPath:mInputFile isDirectory:&inputIsDirectory];
    
    if (inputIsDirectory)
    {
        NSDirectoryEnumerator* directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:mInputFile];
        
        NSString* fileName = NULL;
        
        do
        {
            fileName = [directoryEnumerator nextObject];
            
            if (fileName == NULL)
            {
                break;
            }
            
            if ([[fileName pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame)
            {
                [self GenerateMipmapsForFile:[mInputFile stringByAppendingString:fileName]];
            }
            
        } while(fileName != NULL);
    }
    else
    {
        [self GenerateMipmapsForFile:mInputFile];
    }
    
        
    printf("Generate Mipmaps:\tInput %s\n\t\t\tOutput %s\n", [mInputFile UTF8String], [mOutputDirectory UTF8String]);
}

-(void)GenerateMipmapsForFile:(NSString*)inFileName
{
    static const int KERNEL_SIZE = 4;

    PNGInfo pngInfo;
    ReadPNG(inFileName, TEX_ADDRESSING_8, &pngInfo);
    
    ImageBufferParams imageBufferParams;
    [ImageBuffer InitDefaultParams:&imageBufferParams];
    
    imageBufferParams.mWidth = pngInfo.mWidth;
    imageBufferParams.mHeight = pngInfo.mHeight;
    imageBufferParams.mData = (u8*)pngInfo.mImageData;
    
    int curWidth = imageBufferParams.mWidth / 2;
    int curHeight = imageBufferParams.mHeight / 2;
    int level = 0;

    NSString* inputFileName = [inFileName lastPathComponent];
    NSString* extension = [inputFileName pathExtension];
    
    const char* inputFileNameBuffer = [inputFileName UTF8String];
    const char* extensionBuffer = [extension UTF8String];
    
    char* inputFileNameOnly = malloc(strlen(inputFileNameBuffer) + 1);
    strcpy(inputFileNameOnly, inputFileNameBuffer);
    inputFileNameOnly[strlen(inputFileNameBuffer) - 1 - strlen(extensionBuffer)] = 0;
    
    // First, write out the base level
    
    NSString* baseLevelFileName = [NSString stringWithFormat:@"%s_0.png", inputFileNameOnly];
    WritePNG((u8*)pngInfo.mImageData, [mOutputDirectory stringByAppendingString:baseLevelFileName], pngInfo.mWidth, pngInfo.mHeight);
    
    while (true)
    {
        KaiserFilterParams params;
        
        [KaiserFilter InitDefaultParams:&params];
            
        params.mInputBuffer = [(ImageBuffer*)[ImageBuffer alloc] InitWithParams:&imageBufferParams];
        params.mKernelSize = KERNEL_SIZE;
        params.mPremultipliedAlpha = FALSE;
        params.mBorder = 0;
        params.mDynamicOutput = TRUE;
        
        KaiserFilter* kaiserFilter = [(KaiserFilter*)[KaiserFilter alloc] InitWithParams:&params];
        
        [kaiserFilter SetOutputSizeX:curWidth Y:curHeight];
        [kaiserFilter Update:0.0];
                
        NSString* outputFileName = [NSString stringWithFormat:@"%s_%d.png", inputFileNameOnly, level + 1];
        
        ImageBuffer* outputBuffer = [kaiserFilter GetOutputBuffer];
        WritePNG(   (unsigned char*)[outputBuffer GetData], [mOutputDirectory stringByAppendingString:outputFileName],
                    [outputBuffer GetWidth], [outputBuffer GetHeight]);
        
        [kaiserFilter release];

        curWidth /= 2;
        curHeight /= 2;
        
        if ((curWidth == 0) || (curHeight == 0))
        {
            break;
        }
        
        level++;
    }
}

static const char* GENERATE_TEXT_FONT_NAME = "-fontName";
static const char* GENERATE_TEXT_FONT_SIZE = "-fontSize";
static const char* GENERATE_TEXT_BORDER_SIZE = "-borderSize";
static const char* GENERATE_TEXT_STROKE_COLOR = "-strokeColor";
static const char* GENERATE_TEXT_FILL_COLOR = "-fillColor";
static const char* GENERATE_TEXT_STROKE_SIZE = "-strokeSize";
static const char* GENERATE_TEXT_BLOOM = "-bloom";

-(void)PerformGenerateText
{
    TextTextureParams textParams;
    NSString* fontPath = NULL;
    NSString* fontName = NULL;
    BOOL bloom = FALSE;
    BOOL stingerOutput = FALSE;
    BOOL generateRetina = FALSE;
    
    [TextTextureBuilder InitDefaultParams:&textParams];
    
    for (int curArgIndex = 0; curArgIndex < [mArguments count]; curArgIndex++)
    {
        NSString* curArg = [mArguments objectAtIndex:curArgIndex];
        
        if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:FONT_PATH_PARAMETER_NAME]] == NSOrderedSame)
        {
            fontPath = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_FONT_NAME]] == NSOrderedSame)
        {
            fontName = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_FONT_SIZE]] == NSOrderedSame)
        {
            NSString* fontSize = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
            
            textParams.mPointSize = [fontSize intValue];
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_BORDER_SIZE]] == NSOrderedSame)
        {
            NSString* border = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
            
            int borderVal = [border intValue];
            
            textParams.mLeadWidth = borderVal;
            textParams.mLeadHeight = borderVal;
            textParams.mTrailWidth = borderVal;
            textParams.mTrailHeight = borderVal;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_STROKE_COLOR]] == NSOrderedSame)
        {
            NSString* strokeColor = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
            
            const char* strokeColorCStr = [strokeColor UTF8String];
            
            if ((strokeColorCStr[0] == '0') && (toupper(strokeColorCStr[1]) == 'X'))
            {
                sscanf(strokeColorCStr, "%x", &textParams.mStrokeColor);
            }
            else
            {
                sscanf(strokeColorCStr, "%d", &textParams.mStrokeColor);
            }
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_FILL_COLOR]] == NSOrderedSame)
        {
            NSString* fillColor = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
            
            const char* fillColorCStr = [fillColor UTF8String];
            
            if ((fillColorCStr[0] == '0') && (toupper(fillColorCStr[1]) == 'X'))
            {
                sscanf(fillColorCStr, "%x", &textParams.mColor);
            }
            else
            {
                sscanf(fillColorCStr, "%d", &textParams.mColor);
            }
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_STROKE_SIZE]] == NSOrderedSame)
        {
            NSString* strokeSize = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
            
            textParams.mStrokeSize = [strokeSize intValue];
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_STRING_PARAMETER_NAME]] == NSOrderedSame)
        {
            textParams.mString = [mArguments objectAtIndex:(curArgIndex + 1)];
            curArgIndex++;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_TEXT_BLOOM]] == NSOrderedSame)
        {
            bloom = TRUE;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_STINGER_FLAG_NAME]] == NSOrderedSame)
        {
            stingerOutput = TRUE;
        }
        else if ([curArg caseInsensitiveCompare:[NSString stringWithUTF8String:GENERATE_RETINA_FLAG_NAME]] == NSOrderedSame)
        {
            generateRetina = TRUE;
        }
        else
        {
            NSAssert(FALSE, @"Unknown argument provided %@", curArg);
        }
    }
    
    NSAssert(fontPath != NULL, @"No font path was specified, define the NEON_IMAGE_PROCESSOR_FONT_PATH environment variable to point to the fonts");
    
    if (!stingerOutput)
    {
        NSAssert(!generateRetina, @"We don't currently support pregenerated strings for retina dsplay.  Generate normal text at double the point size");
    }
    
    NSString* assetPath = NULL;
    
    if (fontPath == NULL)
    {
        assetPath = [fontPath stringByAppendingFormat:@"/%@", textParams.mFontName];
    }
    else
    {
        assetPath = [fontPath stringByAppendingFormat:@"/%@", fontName];
    }
     
    NSNumber* texHandle = [[ResourceManager GetInstance] LoadAssetWithPath:assetPath];
    NSData* fontData = [[ResourceManager GetInstance] GetDataForHandle:texHandle];
    
    textParams.mFontData = fontData;
    textParams.mFontName = NULL;
    textParams.mPremultipliedAlpha = TRUE;
    
    StingerHeader stingerHeader;
    
    memset(&stingerHeader, 0, sizeof(stingerHeader));
    
    stingerHeader.mMagicNumber = STINGER_HEADER_MAGIC_NUMBER;
    stingerHeader.mMajorVersion = STINGER_MAJOR_VERSION;
    stingerHeader.mMinorVersion = STINGER_MINOR_VERSION;
    stingerHeader.mNumEmbeddedStingers = 0;
    
    FILE* stingerFile = NULL;
    
    if (stingerOutput)
    {
        stingerFile = fopen([mOutputFile UTF8String], "w");
    }
    
    int curOffset = sizeof(StingerHeader);
    
    TextCorePNGInfo pngInfo[2];
    memset(pngInfo, 0, sizeof(pngInfo));
    
    for (int curGenerateRetina = 0; curGenerateRetina < 2; curGenerateRetina++)
    {
        if (curGenerateRetina && !generateRetina)
        {
            break;
        }
                
        if (curGenerateRetina)
        {
            textParams.mStrokeSize *= 2;
            textParams.mPointSize *= 2;
            
            textParams.mLeadWidth *= 2;
            textParams.mLeadHeight *= 2;
            textParams.mTrailWidth *= 2;
            textParams.mTrailHeight *= 2;
        }
        
        [self GenerateTextCore:&textParams bloom:bloom outputStinger:stingerOutput retina:curGenerateRetina pngInfo:&pngInfo[curGenerateRetina]];

        if (stingerOutput)
        {
            NSAssert(pngInfo[curGenerateRetina].mPNGData != NULL, @"No PNG data returned, but this is required for stingers.");
            NSAssert(pngInfo[curGenerateRetina].mPNGSize != 0, @"Zero length PNG data returned.  This is invalid.");
            
            stingerHeader.mContentWidth[curGenerateRetina] = textParams.mEndX - textParams.mStartX;
            stingerHeader.mContentHeight[curGenerateRetina] = textParams.mEndY - textParams.mStartY;
            
            // All border parameters are the same, so just choose any one of them
            stingerHeader.mBorderSize[curGenerateRetina] = textParams.mLeadWidth;
            
            stingerHeader.mStingerOffsets[curGenerateRetina] = curOffset;
            stingerHeader.mNumEmbeddedStingers++;
            
            curOffset += pngInfo[curGenerateRetina].mPNGSize;
        }
    }
    
    if (stingerOutput)
    {
        fwrite(&stingerHeader, sizeof(stingerHeader), 1, stingerFile);
        
        for (int i = 0; i < stingerHeader.mNumEmbeddedStingers; i++)
        {
            fwrite(pngInfo[i].mPNGData, pngInfo[i].mPNGSize, 1, stingerFile);
        }
        
        fclose(stingerFile);
    }
    
    [[ResourceManager GetInstance] UnloadAssetWithHandle:texHandle];
}

-(void)GenerateTextCore:(TextTextureParams*)inTextParams bloom:(BOOL)inBloom outputStinger:(BOOL)inOutputStinger
    retina:(BOOL)inRetina pngInfo:(TextCorePNGInfo*)outPNGInfo
{
    Texture* textTexture = [[TextTextureBuilder GetInstance] GenerateTextureWithParams:inTextParams];
    
    outPNGInfo->mPNGData = NULL;
    outPNGInfo->mPNGSize = 0;
    
    if (!inBloom)
    {
        NSAssert([[mOutputFile pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame, @"Only .png output files are supported");
        NSAssert(inOutputStinger == FALSE, @"We only support output as stingers when bloom is on.");
        WritePNG((u8*)textTexture->mTexBytes, mOutputFile, textTexture->mGLWidth, textTexture->mGLHeight);
    }
    else
    {
        NSString* pathExtension = [mOutputFile pathExtension];
        
        if (!inOutputStinger)
        {
            NSAssert([pathExtension caseInsensitiveCompare:@"papng"] == NSOrderedSame, @"Only .papng output files are supported when bloom is specified");
        }
        else
        {
            NSAssert([pathExtension caseInsensitiveCompare:@"stinger"] == NSOrderedSame, @"Only .stinger output files for stingers with bloom");
        }

        BloomGaussianParams params;
        
        [BloomGaussianFilter InitDefaultParams:&params];
        
        params.mInputTexture = textTexture;
        params.mNumDownsampleLevels = 5;
        params.mBorder = 0;
        params.mPremultipliedAlpha = TRUE;
        
        if (inRetina)
        {
            params.mKernelSize = (params.mKernelSize * 2) + 1;
        }

        BloomGaussianFilter* bloomFilter = [(BloomGaussianFilter*)[BloomGaussianFilter alloc] InitWithParams:&params];
    
        [bloomFilter Update:0.0];

        NSMutableArray* textureLayers = [bloomFilter GetTextureLayers];
        Texture* largestTexture = [textureLayers objectAtIndex:([textureLayers count] - 2)];
        
        [[GLHelper GetInstance] InitializeDrawableWithWidth:largestTexture->mGLWidth height:largestTexture->mGLHeight];

        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);

        [bloomFilter SetDrawBaseLayer:TRUE];
        [bloomFilter Draw];
        
        if (!inOutputStinger)
        {
            SaveScreenRect(mOutputFile, largestTexture->mWidth, largestTexture->mHeight);
        }
        else
        {
            unsigned char* outputData = malloc(largestTexture->mWidth * largestTexture->mHeight * 4);
                        
            SaveScreenRectMemory(outputData, largestTexture->mWidth, largestTexture->mHeight);
            WritePNGMemory(outputData, largestTexture->mWidth, largestTexture->mHeight, &outPNGInfo->mPNGData, &outPNGInfo->mPNGSize);
            
            free(outputData);
        }
    }
}

@end