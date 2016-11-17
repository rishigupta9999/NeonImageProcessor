//
//  PNGUtilities.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "Texture.h"

typedef struct
{
    u32     mWidth;
    u32     mHeight;
    u32*    mImageData;
} PNGInfo;

BOOL ReadPNG(NSString* inFilename, TexAddressing inAddressing, PNGInfo* outInfo);
BOOL ReadPNGBytes(unsigned char* inBytes, TexAddressing inAddressing, PNGInfo* outInfo);
BOOL ReadPNGData(NSData* inData, TexAddressing inAddressing, PNGInfo* outInfo);

void WritePNG(unsigned char* inImageData, NSString* inFilename, int inWidth, int inHeight);
void WritePNGMemory(unsigned char* inImageData, int inWidth, int inHeight, unsigned char** outPNGData, u32* outPNGDataSize);