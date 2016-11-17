//
//  BigFileDefines.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#pragma once

#define NEON21_BIGFILE_MAJOR_VERSION   1
#define NEON21_BIGFILE_MINOR_VERSION   0

#define BIGFILE_FILENAME_LENGTH        32

typedef struct
{
    int mMajorVersion;
    int mMinorVersion;
    int mNumFiles;
    // variable length table of contents goes after here in the form of TOC entries
} BigFileHeader;

typedef struct
{
    int     mOffset;                    // Offset from the start of the file
    char    mFilename[BIGFILE_FILENAME_LENGTH];     // File name (ASCII)
} TOCEntry;
