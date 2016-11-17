//
//  Filter.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

@class Texture;

@interface Filter : NSObject
{
}

-(Filter*)Init;
-(void)dealloc;

-(void)Update:(CFTimeInterval)inTimeStep;

@end