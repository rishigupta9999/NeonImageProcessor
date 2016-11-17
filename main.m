#import <AppKit/NSOpenGL.h>
#import <OpenGL/CGLRenderers.h>
#import <stdio.h>

#import "ResourceManager.h"
#import "TextureManager.h"
#import "TextTextureBuilder.h"

#import "GLHelper.h"

#import "Operation.h"

void InitOpenGL()
{
    // All rendering is offscreen to FBOs and then output to PNGs.  We don't need to initialize
    // the window system, which saves a ton of code.
    
    NSOpenGLPixelFormatAttribute attr[] =
    {
		NSOpenGLPFAPixelBuffer,
        NSOpenGLPFARendererID, kCGLRendererGenericID,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFADepthSize, 32,
		0 };
        
	NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];

    NSOpenGLContext* openGLContext = [  [NSOpenGLContext alloc]
                                        initWithFormat:format
                                        shareContext:NULL];
                    
    [openGLContext makeCurrentContext];
}

BOOL GetInputOutputParameters(int argc, const char* argv[], NSString** outInputFile, NSString** outOutputFile)
{
    if (argc != 4)
    {
        return FALSE;
    }
    else
    {
        *outInputFile = [NSString stringWithUTF8String:argv[2]];
        *outOutputFile = [NSString stringWithUTF8String:argv[3]];
    }
    
    return TRUE;
}

BOOL GetBloomParameters(int argc, const char* argv[], NSString** outInputFile, NSString** outOutputFile, NSMutableArray* outExtraArguments)
{
    NSString* inputFile = NULL;
    NSString* outputFile = NULL;
    BOOL success = FALSE;
    
    inputFile = [NSString stringWithUTF8String:argv[argc - 2]];
    outputFile = [NSString stringWithUTF8String:argv[argc - 1]];
    
	*outInputFile = inputFile;
    *outOutputFile = outputFile;
	
	if ((outInputFile != NULL) && (outOutputFile != NULL))
    {
        success = TRUE;
    }
    
    if (success)
    {
        success = FALSE;
        
        if ([[*outOutputFile pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame)
        {
            success = TRUE;
        }
        
        if ([[*outOutputFile pathExtension] caseInsensitiveCompare:@"papng"] == NSOrderedSame)
        {
            success = TRUE;
        }
    }
	
	if (success)
	{
		for (int curArg = 2; curArg < (argc - 2); curArg++)
        {
            NSString* curString = [NSString stringWithUTF8String:argv[curArg]];
            [outExtraArguments addObject:curString];
        }
	}
    
    return success;
}

BOOL GetPremultiplyAlphaParameters(int argc, const char* argv[], NSString** outInputFile, NSString** outOutputFile)
{
    BOOL success = GetInputOutputParameters(argc, argv, outInputFile, outOutputFile);
    
    if (success)
    {
        success = FALSE;
        
        if ([[*outOutputFile pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame)
        {
            success = TRUE;
        }
        
        if ([[*outOutputFile pathExtension] caseInsensitiveCompare:@"papng"] == NSOrderedSame)
        {
            success = TRUE;
        }
    }
    
    return success;
}

BOOL GetGenerateMipmapParameters(int argc, const char* argv[], NSString** outInputFile, NSString** outOutputDirectory)
{
    BOOL success = GetInputOutputParameters(argc, argv, outInputFile, outOutputDirectory);
    
    if (success)
    {
        success = FALSE;
        
        if ([[*outInputFile pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame)
        {
            success = TRUE;
        }
        
        BOOL directory = FALSE;
        
        [[NSFileManager defaultManager] fileExistsAtPath:*outInputFile isDirectory:&directory];
        
        if (directory)
        {
            success = TRUE;
        }
    }
    
    return success;
}

BOOL GetGenerateTextParameters(int argc, const char* argv[], NSMutableArray* outExtraArguments, NSString** outOutputFile)
{
    NSString* inputText = NULL;
    NSString* outputFile = NULL;
    BOOL success = FALSE;
    
    inputText = [NSString stringWithUTF8String:argv[argc - 2]];
    outputFile = [NSString stringWithUTF8String:argv[argc - 1]];
    
    *outOutputFile = outputFile;
    
    char *fontPath = getenv("NEON_IMAGE_PROCESSOR_FONT_PATH");
	
	if (fontPath == NULL)
	{
		NSLog(@"Font path isn't set.  Make sure that NEON_IMAGE_PROCESSOR_FONT_PATH is defined.");
	}
    
    if ((inputText != NULL) && (outOutputFile != NULL) && (fontPath != NULL))
    {
        success = TRUE;
    }
    
    if (success)
    {
        [outExtraArguments addObject:[NSString stringWithUTF8String:FONT_PATH_PARAMETER_NAME]];
        [outExtraArguments addObject:[NSString stringWithUTF8String:fontPath]];
        
        [outExtraArguments addObject:[NSString stringWithUTF8String:GENERATE_TEXT_STRING_PARAMETER_NAME]];
        [outExtraArguments addObject:inputText];
        
        for (int curArg = 2; curArg < (argc - 2); curArg++)
        {
            NSString* curString = [NSString stringWithUTF8String:argv[curArg]];
            [outExtraArguments addObject:curString];
        }
    }
        
    return success;
}

BOOL GetGenerateAtlasParameters(int argc, const char* argv[], NSString** outInputDirectory, NSString** outOutputDirectory)
{
    BOOL success = GetInputOutputParameters(argc, argv, outInputDirectory, outOutputDirectory);
    
    if (success)
    {
        success = FALSE;
        
        BOOL directory = FALSE;
        
        [[NSFileManager defaultManager] fileExistsAtPath:*outInputDirectory isDirectory:&directory];
        
        if (directory)
        {
            success = TRUE;
        }
    }
    
    return success;
}

void DisplayHelp()
{
    printf("Usage is Neon21ImageProcessor <Action> <Input File> <Output File>\n\n");
    
    printf("Action is one of the following:\n");
    printf("-bloom\n");
    printf("-premultiplyAlpha\n");
    printf("-generateMipmaps\n");
    printf("-generateText\n");
    printf("-generateStinger\n");
    printf("-generateAtlas\n");
    printf("\n");
    printf("Run with one of these arguments specified to get more information about the argument syntax\n");
}

Operation* ParseArgs(int argc, const char* argv[])
{
    if (argc == 1)
    {
        printf("This program takes at least one argument.  Type --help for options\n");
    }
    else
    {
        NSString* actionArg = [NSString stringWithUTF8String:argv[1]];
        
        if (actionArg != NULL)
        {
            if ([actionArg caseInsensitiveCompare:@"-help"] == NSOrderedSame)
            {
                DisplayHelp();
            }
            else if ([actionArg caseInsensitiveCompare:@"-bloom"] == NSOrderedSame)
            {
				static const int BLOOM_INITIAL_ARGUMENT_CAPACITY = 3;

                NSString* inputFile;
                NSString* outputFile;
				NSMutableArray* argArray = [[NSMutableArray alloc] initWithCapacity:BLOOM_INITIAL_ARGUMENT_CAPACITY];
                
                BOOL success = GetBloomParameters(argc, argv, &inputFile, &outputFile, argArray);
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_BLOOM];
                    
                    [operation SetInputFile:inputFile];
                    [operation SetOutputFile:outputFile];
					[operation SetArguments:argArray];
                    
                    return operation;
                }
                else
                {
                    printf("Bloom operation needs an input and output file.  Input as PNG, output as either PNG or PAPNG\n");
                }
            }
            else if ([actionArg caseInsensitiveCompare:@"-premultiplyAlpha"] == NSOrderedSame)
            {
                NSString* inputFile;
                NSString* outputFile;
                
                BOOL success = GetPremultiplyAlphaParameters(argc, argv, &inputFile, &outputFile);
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_PREMULTIPLY_ALPHA];
                    
                    [operation SetInputFile:inputFile];
                    [operation SetOutputFile:outputFile];
                    
                    return operation;
                }
                else
                {
                    printf("Premultiply Alpha operation needs an input file in PNG format and an output file in PAPNG format.\n");
                }
            }
            else if ([actionArg caseInsensitiveCompare:@"-generateMipmaps"] == NSOrderedSame)
            {
                NSString* inputFile;
                NSString* outputDirectory;
                
                BOOL success = GetGenerateMipmapParameters(argc, argv, &inputFile, &outputDirectory);
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_GENERATE_MIPMAPS];
                    
                    [operation SetInputFile:inputFile];
                    [operation SetOutputDirectory:outputDirectory];
                    
                    return operation;
                }
                else
                {
                    printf("Generate Mipmap operation needs an input file in PNG format, or an input directory.  Output must be a directory.\n");
                }
            }
            else if ([actionArg caseInsensitiveCompare:@"-generateText"] == NSOrderedSame)
            {
                static const int TEXT_INITIAL_ARGUMENT_CAPACITY = 5;
                
                NSString* outputFile;
                NSMutableArray* argArray = [[NSMutableArray alloc] initWithCapacity:TEXT_INITIAL_ARGUMENT_CAPACITY];
                
                BOOL success = GetGenerateTextParameters(argc, argv, argArray, &outputFile);
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_GENERATE_TEXT];
                    
                    [operation SetOutputFile:outputFile];
                    [operation SetArguments:argArray];
                    
                    return operation;
                }
                else
                {
                    printf("Generate Text operation needs a variable number of parameters (see the exportstringers.sh script)\n");
                    printf("followed by the string to render and the output filename\n");
                }
            }
            else if ([actionArg caseInsensitiveCompare:@"-generateStinger"] == NSOrderedSame)
            {
                static const int TEXT_INITIAL_ARGUMENT_CAPACITY = 5;
                
                NSString* outputFile;
                NSMutableArray* argArray = [[NSMutableArray alloc] initWithCapacity:TEXT_INITIAL_ARGUMENT_CAPACITY];
                
                BOOL success = GetGenerateTextParameters(argc, argv, argArray, &outputFile);
                
                [argArray addObject:[NSString stringWithUTF8String:GENERATE_STINGER_FLAG_NAME]];
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_GENERATE_TEXT];
                    
                    [operation SetOutputFile:outputFile];
                    [operation SetArguments:argArray];
                    
                    return operation;
                }
                else
                {
                    printf("Generate Stinger operation needs a variable number of parameters (see the exportstringers.sh script)\n");
                    printf("followed by the string to render and the output filename\n");
                }
            }
            else if ([actionArg caseInsensitiveCompare:@"-generateAtlas"] == NSOrderedSame)
            {                
                assert(false); //-generateAtlas is unimplemented;
                
                NSString* inputDirectory;
                NSString* outputDirectory;
                
                BOOL success = GetGenerateAtlasParameters(argc, argv, &inputDirectory, &outputDirectory);
                
                if (success)
                {
                    Operation* operation = [Operation OperationWithType:OPERATION_GENERATE_ATLAS];
                    
                    [operation SetInputFile:inputDirectory];
                    [operation SetOutputDirectory:outputDirectory];
                    
                    return operation;
                }
                else
                {
                    printf("Generate Atlas operation needs an input directory containing .png files (all other files will be ignored).\n");
                    printf("Output must be a filename ending in .atlas.\n");
                }
            }
            else
            {
                printf("Unrecognized operation: %s\n", argv[1]);
            }
        }
    }
    
    return NULL;
}

void InitEngine()
{
    [ResourceManager CreateInstance];
    [TextureManager CreateInstance];
    [TextTextureBuilder CreateInstance];
    
    [GLHelper CreateInstance];
}

void TerminateEngine()
{
    [ResourceManager DestroyInstance];
    [TextureManager DestroyInstance];
    [TextTextureBuilder DestroyInstance];
    
    [GLHelper DestroyInstance];
}

int main (int argc, const char * argv[])
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    InitOpenGL();
    Operation* operation = ParseArgs(argc, argv);
    
    if (operation)
    {
        InitEngine();
        [operation Perform];
        TerminateEngine();
    }
    
    [pool drain];
    
    return 0;
}
