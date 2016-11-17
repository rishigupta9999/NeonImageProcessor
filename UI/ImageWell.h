//
//  ImageWell.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.

#import "UIObject.h"

typedef struct
{
    Texture*   mTexture;
} ImageWellParams;

@interface ImageWell : UIObject
{
    Texture*        mTexture;
}

-(ImageWell*)InitWithParams:(ImageWellParams*)inParams;
-(void)dealloc;

-(void)DrawOrtho;

@end