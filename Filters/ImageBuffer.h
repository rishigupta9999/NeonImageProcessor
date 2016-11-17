//
//  ImageBuffer.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

typedef struct
{
    u32  mWidth;
    u32  mHeight;
    u32  mEffectiveWidth;
    u32  mEffectiveHeight;
    u32  mBytesPerPixel;
    u8*  mData;
    BOOL mDataOwner;
} ImageBufferParams;

typedef enum
{
    WRAP_MODE_ZERO,
    WRAP_MODE_REFLECT,
    WRAP_MODE_MAX
} WrapMode;

@interface ImageBuffer : NSObject
{
    WrapMode          mWrapMode;

    ImageBufferParams mParams;
}

-(ImageBuffer*)InitWithParams:(ImageBufferParams*)inParams;
-(void)dealloc;

+(void)InitDefaultParams:(ImageBufferParams*)outParams;

-(void)SetWrapMode:(WrapMode)inWrapMode;

-(u32)GetWidth;
-(u32)GetHeight;
-(u32)GetEffectiveWidth;
-(u32)GetEffectiveHeight;

-(u32)SampleX:(s32)inX Y:(s32)inY;
-(void)SetSampleX:(u32)inX Y:(u32)inY value:(u32)inValue;

-(u8*)GetData;

@end