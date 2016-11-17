//
//  TextureManager.h
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "Texture.h"

@interface TextureManager :  NSObject
{
    
}

+(void)CreateInstance;
+(void)DestroyInstance;
+(TextureManager*)GetInstance;

-(void)Init;
-(void)Term;

-(Texture*)TextureWithName:(NSString*)inName;
-(Texture*)TextureWithName:(NSString*)inName textureParams:(TextureParams*)inParams;

@end