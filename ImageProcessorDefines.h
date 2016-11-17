/*
 *  ImageProcessorDefines.h
 *  Neon21ImageProcessor
 *
 *  Copyright 2010 Neon Games. All rights reserved.
 *
 */
 
#define STINGER_HEADER_MAGIC_NUMBER ('STGR')

#define STINGER_MAJOR_VERSION       (1)
#define STINGER_MINOR_VERSION       (0)
 
typedef struct
{
    u32 mMagicNumber;
    u32 mMajorVersion;
    u32 mMinorVersion;
    
    u32 mContentWidth[2];
    u32 mContentHeight[2];
    
    u32 mBorderSize[2];
    
    u32 mNumEmbeddedStingers;
    u32 mStingerOffsets[2];
} StingerHeader;