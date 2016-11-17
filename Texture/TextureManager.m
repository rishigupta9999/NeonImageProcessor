//
//  TextureManager.m
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "TextureManager.h"
#import "ResourceManager.h"

#import "PNGTexture.h"
#import "PVRTCTexture.h"

static TextureManager* sInstance = NULL;

@implementation TextureManager

+(void)CreateInstance
{
    NSAssert(sInstance == NULL, @"Trying to create TextureManager when one already exists.");
    
    sInstance = [TextureManager alloc];
    [sInstance Init];
}

+(void)DestroyInstance
{
    NSAssert(sInstance != NULL, @"No texture manager exists.");
    
    [sInstance Term];
    [sInstance release];
}

+(TextureManager*)GetInstance
{
    return sInstance;
}

-(void)Init
{
}

-(void)Term
{
}

-(Texture*)TextureWithName:(NSString*)inName
{
    TextureParams params;
    
    [Texture InitDefaultParams:&params];
    
    return [self TextureWithName:inName textureParams:&params];
}

-(Texture*)TextureWithName:(NSString*)inName textureParams:(TextureParams*)inParams
{
    NSNumber*   resourceHandle = [[ResourceManager GetInstance] LoadAssetWithName:inName];
    NSData*     texData = [[ResourceManager GetInstance] GetDataForHandle:resourceHandle];

    Texture*    retTexture = NULL;
    
    if ([[inName pathExtension] caseInsensitiveCompare:@"PNG"] == NSOrderedSame)
    {
        retTexture = [[PNGTexture alloc] InitWithData:texData textureParams:inParams];
        [retTexture autorelease];
    }
    else if ([[inName pathExtension] caseInsensitiveCompare:@"PAPNG"] == NSOrderedSame)
    {
        retTexture = [[PNGTexture alloc] InitWithData:texData textureParams:inParams];
        [retTexture autorelease];
        
        retTexture->mPremultipliedAlpha = TRUE;
    }

#if TARGET_OS_IPHONE
    else if ([[inName pathExtension] caseInsensitiveCompare:@"PVRTC"] == NSOrderedSame)
    {
        retTexture = [[PVRTCTexture alloc] InitWithData:texData textureParams:inParams];
        [retTexture autorelease];
    }
#endif
    else
    {
        NSAssert(FALSE, @"Unknown texture type");
    }
    
    retTexture->mDebugName = inName;
    [retTexture->mDebugName retain];
    
    [[ResourceManager GetInstance] UnloadAssetWithHandle:resourceHandle];
    
    return retTexture;
}

@end