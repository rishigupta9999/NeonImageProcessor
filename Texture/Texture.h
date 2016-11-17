//
//  Texture.h
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "TextureAtlas.h"

typedef enum
{
    TEX_ADDRESSING_8,
    TEX_ADDRESSING_32
} TexAddressing;

typedef enum
{
    TEX_DATA_RETAIN,
    TEX_DATA_DISPOSE
} TexDataLifetime;

typedef struct
{
    TexAddressing   mTexAddressing;
    TexDataLifetime mTexDataLifetime;
    TextureAtlas*   mTextureAtlas;
    GLenum          mMagFilter;
    GLenum          mMinFilter;
} TextureParams;

@interface Texture : NSObject
{
    @public
        u32             mTexName;
        u32*            mTexBytes;
        int             mFileLength;
        
        u32     mHeight;
        u32     mWidth;
                
        u32     mGLHeight;
        u32     mGLWidth;
        
        GLenum  mFormat;
        GLenum  mType;
        
        BOOL    mPremultipliedAlpha;
        
        TextureParams   mParams;
        NSString*       mDebugName;
        
        TextureAtlasInfo   mTextureAtlasInfo;
        
        u32**           mSrcMipMapTexBytes;
        u32**           mMipMapTexBytes;
    
    @protected
        // If a texture's contents can be respecified later, then these will indicate
        // the maximum dimensions.  Otherwise these will remain at 0 (meaning the fields
        // are to be ignored).
        
        u32     mMaxHeight;
        u32     mMaxWidth;
}

-(Texture*)Init;
+(void)InitDefaultParams:(TextureParams*)outParams;
+(void)RoundToValidDimensionsWidth:(u32)inWidth Height:(u32)inHeight ValidWidth:(u32*)outWidth ValidHeight:(u32*)outHeight;

-(void)dealloc;
-(void)FreeMipMapLayers;

-(void)Bind;
+(void)Unbind;
-(void)CreateGLTexture;
-(Texture*)InitWithData:(NSData*)inData textureParams:(TextureParams*)inParams;
-(Texture*)InitWithMipMapData:(NSMutableArray*)inData textureParams:(TextureParams*)inParams;
-(void)VerifyDimensions;

-(u32*)PadTextureData:(u32*)inTexData srcWidth:(u32)inSrcWidth srcHeight:(u32)inSrcHeight destWidth:(u32)inDestWidth destHeight:(u32)inDestHeight;

-(u32)GetSizeBytes;

-(u32)GetTexel:(CGPoint*)inPoint;
-(void)FreeClientData;

-(void)WritePPM:(NSString*)inFileName;

-(void)SetMaxWidth:(u32)inWidth;
-(u32)GetMaxWidth;

-(void)SetMaxHeight:(u32)inHeight;
-(u32)GetMaxHeight;

-(void)SetMipMapData:(u32*)inData level:(u32)inLevel;

-(u32)GetNumMipMapLevels;
-(u32)GetNumSrcMipMapLevels;
-(u32)GetTextureLayerIndexForMipMapLevel:(u32)inMipMapLevel;

-(void)DumpContents;

@end