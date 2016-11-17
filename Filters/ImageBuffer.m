//
//  ImageBuffer.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

#import "ImageBuffer.h"

@implementation ImageBuffer

-(ImageBuffer*)InitWithParams:(ImageBufferParams*)inParams
{
    memcpy(&mParams, inParams, sizeof(ImageBufferParams));
    
    if (mParams.mEffectiveWidth == 0)
    {
        mParams.mEffectiveWidth = mParams.mWidth;
    }
    
    if (mParams.mEffectiveHeight == 0)
    {
        mParams.mEffectiveHeight = mParams.mHeight;
    }
    
    mWrapMode = WRAP_MODE_ZERO;
    
    NSAssert(mParams.mBytesPerPixel == 4, @"Support for other bit depths probably won't work");
    
    return self;
}

-(void)dealloc
{
    if (mParams.mDataOwner)
    {
        free(mParams.mData);
    }
    
    [super dealloc];
}

+(void)InitDefaultParams:(ImageBufferParams*)outParams
{
    outParams->mWidth = 0;
    outParams->mHeight = 0;
    outParams->mEffectiveWidth = 0;
    outParams->mEffectiveHeight = 0;
    outParams->mData = NULL;
    outParams->mDataOwner = FALSE;
    outParams->mBytesPerPixel = 4;
}

-(void)SetWrapMode:(WrapMode)inWrapMode
{
    mWrapMode = inWrapMode;
}

-(u32)GetWidth
{
    return mParams.mWidth;
}

-(u32)GetHeight
{
    return mParams.mHeight;
}

-(u32)GetEffectiveWidth
{
    return mParams.mEffectiveWidth;
}

-(u32)GetEffectiveHeight
{
    return mParams.mEffectiveHeight;
}

-(u32)SampleX:(s32)inX Y:(s32)inY
{
    u32 retVal = 0;
    
    switch(mWrapMode)
    {
        case WRAP_MODE_ZERO:
        {
            if ((inX >= 0) && (inX < mParams.mEffectiveWidth) && (inY >= 0) && (inY < mParams.mEffectiveHeight))
            {
                memcpy(&retVal, &mParams.mData[(inX + (inY * mParams.mWidth)) * mParams.mBytesPerPixel], mParams.mBytesPerPixel);
            }
                        
            break;
        }
        
        case WRAP_MODE_REFLECT:
        {
            s32 rX = inX;
            s32 rY = inY;
            
            while ((rX < 0) || (rX > (mParams.mEffectiveWidth - 1)))
            {
                if (rX < 0)
                {
                    rX = -rX;
                }
                
                if (rX >= mParams.mEffectiveWidth)
                {
                    rX = mParams.mEffectiveWidth + mParams.mEffectiveWidth - rX - 1;
                }
            }

            while ((rY < 0) || (rY > (mParams.mEffectiveHeight - 1)))
            {
                if (rY < 0)
                {
                    rY = -rY;
                }
                if (rY >= mParams.mEffectiveHeight)
                {
                    rY = mParams.mEffectiveHeight + mParams.mEffectiveHeight - rY - 1;
                }
            }

            memcpy(&retVal, &mParams.mData[(rX + (rY * mParams.mWidth)) * mParams.mBytesPerPixel], mParams.mBytesPerPixel);

            break;
        }
        
        default:
        {
            NSAssert(FALSE, @"Unknown sampling mode.");
            break;
        }
    }
    
    return retVal;
}

-(void)SetSampleX:(u32)inX Y:(u32)inY value:(u32)inValue
{
    memcpy( &mParams.mData[(inX + (inY * mParams.mWidth)) * mParams.mBytesPerPixel],
            &inValue, mParams.mBytesPerPixel);
}

-(u8*)GetData
{
    return mParams.mData;
}

@end