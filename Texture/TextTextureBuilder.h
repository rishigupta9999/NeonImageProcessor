//
//  TextTextureBuilder.h
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "Texture.h"
#import "ResourceManager.h"

#include "ft2build.h"
#include "freetype.h"

#include "Color.h"

@class TextureAtlas;

typedef struct
{
    // Input
    NSString*   mFontName;
    NSData*     mFontData;
    u32         mPointSize;
    NSString*   mString;
    u32         mColor;
    u32         mStrokeColor;
    u32         mWidth;
    u32         mLeadWidth;
    u32         mLeadHeight;
    u32         mTrailWidth;
    u32         mTrailHeight;
    u32         mStrokeSize;    // That's what she said
    BOOL        mPremultipliedAlpha;
    TextureAtlas* mTextureAtlas;
    Texture*      mTexture;
    
    // Output
    u32         mStartX;
    u32         mStartY;
    u32         mEndX;
    u32         mEndY;
} TextTextureParams;

@interface FontNode : NSObject
{
    @public
        FT_Face     mFace;
        NSNumber*   mResourceHandle;
}

@end

@interface GlyphSpan : NSObject
{
    @public
        int x;
        int y;
        int width;
        int coverage;
}

@end

@interface TextTextureBuilderCacheEntry : NSObject
{
    @public
        Texture*            mTexture;
        TextTextureParams   mParams;
        
        CFAbsoluteTime      mLastUsedTime;
}

@end

@interface TextTextureBuilder : NSObject
{
    @public
        FT_Library mLibrary;
        
        NSMutableArray* mFontNodes;
        NSMutableArray* mOutlineSpans;
        NSMutableArray* mInsideSpans;
        
        NSMutableArray* mTextureCache;
        
        u32             mCacheSize;
}

+(void)CreateInstance;
+(void)DestroyInstance;
+(TextTextureBuilder*)GetInstance;

-(TextTextureBuilder*)Init;
-(void)dealloc;

+(void)InitDefaultParams:(TextTextureParams*)outParams;

-(Texture*)GenerateTextureWithFont:(NSString*)inFontName PointSize:(u32)inPointSize String:(NSString*)inString Color:(u32)inColor;
-(Texture*)GenerateTextureWithFont:(NSString*)inFontName PointSize:(u32)inPointSize String:(NSString*)inString Color:(u32)inColor Width:(u32)inWidth;
-(Texture*)GenerateTextureWithParams:(TextTextureParams*)inParams;

-(void)GenerateStrokeBitmap:(FT_GlyphSlot)inSlot insideColor:(Color*)inInsideColor outsideColor:(Color*)inOutsideColor;

-(void)AddToCache:(Texture*)inTexture withParams:(TextTextureParams*)inParams;
-(BOOL)CompareParams:(TextTextureParams*)inLeftParams withParams:(TextTextureParams*)inRightParams;
-(Texture*)LookupInCache:(TextTextureParams*)inParams;
-(void)EvictCacheToWatermark;

@end