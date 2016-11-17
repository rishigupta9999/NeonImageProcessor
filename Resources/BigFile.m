//
//  BigFile.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "BigFile.h"

@implementation BigFile

-(BigFile*)InitWithData:(NSData*)inData
{
    unsigned const char* stream = [inData bytes];
    
    mData = inData;
    
    BigFileHeader header;
    
    memcpy(&header, stream, sizeof(BigFileHeader));
    
    NSAssert(header.mMajorVersion == NEON21_BIGFILE_MAJOR_VERSION, @"Major version mismatch during bigfile load");
    NSAssert(header.mMinorVersion == NEON21_BIGFILE_MINOR_VERSION, @"Minor version mismatch during bigfile load");
    
    mNumFiles = 0;
    
    if ((header.mMajorVersion == NEON21_BIGFILE_MAJOR_VERSION) && (header.mMinorVersion == NEON21_BIGFILE_MINOR_VERSION))
    {
        mNumFiles = header.mNumFiles;
        
        mTOC = malloc(sizeof(TOCEntry) * (mNumFiles + 1));
        
        memcpy(mTOC, stream + sizeof(header), sizeof(TOCEntry) * mNumFiles);
        
        // Populate the dummy TOC entry with the end of file
        mTOC[mNumFiles].mOffset = [inData length];
        memset(mTOC[mNumFiles].mFilename, 0, BIGFILE_FILENAME_LENGTH);
    }
    
    return self;
}

-(NSData*)GetFileAtIndex:(int)inIndex
{
    unsigned const char* stream = [mData bytes];
    NSData* retData = NULL;
    
    BOOL validIndex = (inIndex >= 0) && (inIndex < mNumFiles);
    
    NSAssert(validIndex, @"Invalid file index specified during a load from bigfile.\n");
    
    if (validIndex)
    {
        int fileOffset = mTOC[inIndex].mOffset;
        int length = mTOC[inIndex + 1].mOffset - fileOffset;
        
        retData = [NSData dataWithBytes:&stream[fileOffset] length:length];
    }
    
    return retData;
}

@end