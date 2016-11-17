//
//  TextureAtlas.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

@class Texture;

#define TEXTURE_ATLAS_DIMENSION_INVALID    (-1)

typedef struct
{
    int     mWidth;
    int     mHeight;
} TextureAtlasParams;

typedef struct
{
    int     mX;
    int     mY;
    
    float   mSMin;
    float   mTMin;
    
    float   mSMax;
    float   mTMax;
    
    BOOL    mPlaced;
} TextureAtlasInfo;

typedef struct
{
    NSMutableArray* mPlacedTextures;        // All placed textures.  No particular order
    NSMutableArray* mScanlineEntries;       // These are sorted in ascending order by scanline
} TextureFitterContext;


@interface ScanlineEntry : NSObject
{
    @public
        int             mY;
        NSMutableArray* mTextures;          // These are sorted left to right within a scanline
}

-(void)dealloc;

@end

@interface TextureAtlasEntry : NSObject
{
    @public
        Texture*        mTexture;
}

-(TextureAtlasEntry*)Init;
-(void)SetTexture:(Texture*)inTexture;

@end

@interface TextureAtlas : NSObject
{
    // This array is sorted by width
    NSMutableArray* mTextureList;
    
    GLuint  mTextureObject;
    
    int     mAtlasWidth;
    int     mAtlasHeight;
}
-(TextureAtlas*)InitWithParams:(TextureAtlasParams*)inParams;
-(void)dealloc;
+(void)InitDefaultParams:(TextureAtlasParams*)outParams;
+(void)InitTextureAtlasInfo:(TextureAtlasInfo*)outInfo;

-(void)AddTexture:(Texture*)inTexture;
-(void)CreateAtlas;
-(void)CreateGLTexture:(TextureFitterContext*)inContext;
-(void)Bind;
-(BOOL)AtlasCreated;

-(BOOL)FitIntoAtlasWithWidth:(int)width height:(int)height context:(TextureFitterContext*)inContext;
-(BOOL)PackTexture:(Texture*)inTexture context:(TextureFitterContext*)inContext;
-(BOOL)PlaceTexture:(Texture*)inTexture x:(int)inX y:(int)inY context:(TextureFitterContext*)inContext;

-(void)AddTexture:(Texture*)inTexture toScanline:(int)inY context:(TextureFitterContext*)inContext;
-(void)AddScanline:(ScanlineEntry*)inScanline context:(TextureFitterContext*)inContext;
-(void)DetermineRectAtX:(int)inX y:(int)inY width:(int*)outWidth height:(int*)outHeight context:(TextureFitterContext*)inContext;

-(void)ReinitContext:(TextureFitterContext*)context;

-(void)UpdateTexture:(Texture*)inTexture;

-(void)DumpTextureNames;
-(void)DumpScanlineInfo:(TextureFitterContext*)inContext;
-(void)DumpDebugImage:(TextureFitterContext*)inContext;

@end