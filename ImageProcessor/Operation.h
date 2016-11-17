/*
 *  Operation.h
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */
 
#import "TextTextureBuilder.h"
 
typedef enum
{
    OPERATION_BLOOM,
    OPERATION_PREMULTIPLY_ALPHA,
    OPERATION_GENERATE_MIPMAPS,
    OPERATION_GENERATE_TEXT,
    OPERATION_GENERATE_ATLAS,
    OPERATION_MAX,
    OPERATION_INVALID = OPERATION_MAX
} OperationType;

typedef struct
{
    unsigned char*  mPNGData;
    u32             mPNGSize;
} TextCorePNGInfo;

extern const char* FONT_PATH_PARAMETER_NAME;
extern const char* GENERATE_TEXT_STRING_PARAMETER_NAME;
extern const char* GENERATE_STINGER_FLAG_NAME;

@interface Operation : NSObject
{
    OperationType   mType;
    NSString*       mInputFile;
    NSString*       mOutputFile;
    NSString*       mOutputDirectory;
    NSMutableArray* mArguments;
}

+(Operation*)OperationWithType:(OperationType)inType;
-(void)SetInputFile:(NSString*)inString;
-(void)SetOutputFile:(NSString*)inString;
-(void)SetOutputDirectory:(NSString*)inString;
-(void)SetArguments:(NSMutableArray*)inArguments;

-(void)SanitizePaths;

-(void)Perform;
-(void)PerformBloom;
-(void)PerformPremultiplyAlpha;
-(void)PerformGenerateMipmaps;
-(void)PerformGenerateText;

-(void)GenerateTextCore:(TextTextureParams*)inTextParams bloom:(BOOL)inBloom outputStinger:(BOOL)inOutputStinger retina:(BOOL)inRetina pngInfo:(TextCorePNGInfo*)outPNGInfo;

-(void)GenerateMipmapsForFile:(NSString*)inFileName;

-(void)Init;

@end

