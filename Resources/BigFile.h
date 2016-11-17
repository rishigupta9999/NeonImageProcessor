//
//  BigFile.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "BigFileDefines.h"

@interface BigFile : NSObject
{
    TOCEntry*   mTOC;
    int         mNumFiles;
    
    NSData*     mData;
}

-(BigFile*)InitWithData:(NSData*)inData;
-(NSData*)GetFileAtIndex:(int)inIndex;

@end