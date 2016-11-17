//
//  NeonButton.m
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.

#import "NeonButton.h"
#import "TextureManager.h"
#import "BloomGaussianFilter.h"
#import "TextTextureBuilder.h"

#define BORDER_SIZE                 (32.0)
#define BUTTON_HIGHLIGHT_SPEED      (5.0)

#define BUTTON_IDLE_LEAD_TIME               (4.0)
#define BUTTON_IDLE_SEGMENT_TIME            (0.5)
#define BUTTON_IDLE_ACCELERATE_INTENSITY    (0.2)
#define BUTTON_IDLE_MAX_INTENSITY           (0.7)

#define BUTTON_DEFAULT_FADE_SPEED   (10.0)

u32 sNumDownsampleLevels[NEON_BUTTON_QUALITY_NUM] = { 5, 3, 2 };

// Bitfields that indicate which texture layers to keep.  Least significant bit is the most detailed layer.
u32 sDiscardField[NEON_BUTTON_QUALITY_NUM] = { 0xFF, 0x15, 0x14 };

@implementation NeonButton

-(NeonButton*)InitWithParams:(NeonButtonParams*)inParams
{
    [super Init];
    
    memcpy(&mParams, inParams, sizeof(NeonButtonParams));
    
    // We strictly don't need to save all these, but for debugging purposes, the slight memory hit is worth it
    [mParams.mTexName retain];
    [mParams.mBackgroundTexName retain];
    [mParams.mText retain];
    [mParams.mTextFont retain];
    
    mFadeSpeed = mParams.mFadeSpeed;
    
    BloomGaussianFilter* bloomFilter = NULL;

    if (inParams->mTexName != NULL)
    {
        Texture* bloomTexture;
        
        mBaseTexture = [[TextureManager GetInstance] TextureWithName:inParams->mTexName];
        [mBaseTexture retain];
        
        if (inParams->mBackgroundTexName != NULL)
        {
            mBackgroundTexture = [[TextureManager GetInstance] TextureWithName:inParams->mBackgroundTexName];         
            [mBackgroundTexture retain];
               
            bloomTexture = mBackgroundTexture;
        }
        else
        {
            mBackgroundTexture = NULL;
            bloomTexture = mBaseTexture;
        }
        
        if (inParams->mBloomBackground)
        {
            NSAssert(inParams->mQuality >= 0 && inParams->mQuality < NEON_BUTTON_QUALITY_NUM, @"Invalid quality specified");
            
            BloomGaussianParams params;
            [BloomGaussianFilter InitDefaultParams:&params];
            
            params.mInputTexture = bloomTexture;
            params.mBorder = BORDER_SIZE;
            
            // Create all the downsample levels, then delete the ones we don't want
            params.mNumDownsampleLevels = sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH];
            
            bloomFilter = [(BloomGaussianFilter*)[BloomGaussianFilter alloc] InitWithParams:&params];
            
            [bloomFilter Update:0.0];
        }
        
        if (inParams->mText != NULL)
        {
            TextTextureParams textParams;
            
            [TextTextureBuilder InitDefaultParams:&textParams];
            
            textParams.mFontName = inParams->mTextFont;
            textParams.mPointSize = inParams->mTextSize;
            textParams.mColor = GetRGBAU32(&inParams->mTextColor);
            textParams.mString = inParams->mText;
            textParams.mStrokeSize = inParams->mBorderSize;
            textParams.mStrokeColor = GetRGBAU32(&inParams->mBorderColor);
            
            mTextTexture = [[TextTextureBuilder GetInstance] GenerateTextureWithParams:&textParams];
            [mTextTexture retain];
            
            mTextStartX = textParams.mStartX;
            mTextStartY = textParams.mStartY;
            mTextEndX = textParams.mEndX;
            mTextEndY = textParams.mEndY;
            
            [self CalculateTextPlacement];
        }
        else
        {   mTextTexture = NULL;
        
            mTextStartX = 0;
            mTextStartY = 0;
            mTextEndX = 0;
            mTextEndY = 0;
        }
        
        mEnabledPath = [(Path*)[Path alloc] Init];
        mHighlightedPath = [(Path*)[Path alloc] Init];
        mTransitionPath = [(Path*)[Path alloc] Init];
        
        mUsePath = mEnabledPath;
        mPulseState = PULSE_STATE_NORMAL;
                        
        [self BuildEnabledPath];
        
        [mUsePath SetTime:(((float)(rand() % 1000)) / 1000.0f * (float)BUTTON_IDLE_LEAD_TIME)];
    }
    else
    {
        NSAssert(FALSE, @"Untested case, NeonButton with no background texture");
        mBaseTexture = NULL;
    }
    
    if (bloomFilter != NULL)
    {
        [bloomFilter MarkCompleted];
        
        mBlurLayers = [bloomFilter GetTextureLayers];
        [mBlurLayers retain];
        
        int count = [mBlurLayers count];
        
        for (int curLayer = (count - 1); curLayer >= 0; curLayer--)
        {
            int mask = (1 << (sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH] - curLayer - 1));
            
            if ((sDiscardField[mParams.mQuality] & mask) == 0)
            {
                [mBlurLayers removeObjectAtIndex:curLayer];
            }
        }
        
        [bloomFilter release];
    }
    else
    {
        mBlurLayers = [[NSMutableArray alloc] initWithCapacity:1];
        [mBlurLayers addObject:mBackgroundTexture];
    }
    
    mFrameDelay = 3;
    
    return self;
}

-(void)dealloc
{
    // Release textures
    [mBaseTexture release];
    [mBackgroundTexture release];
    [mBlurLayers release];
    [mTextTexture release];
    
    // Release paths
    [mEnabledPath release];
    [mHighlightedPath release];
    [mTransitionPath release];
    
    // Release strings
    [mParams.mTexName release];
    [mParams.mBackgroundTexName release];
    [mParams.mText release];
    [mParams.mTextFont release];
    
    [super dealloc];
}

-(void)Update:(CFTimeInterval)inTimeStep
{    
    if (mFrameDelay > 0)
    {
        mFrameDelay--;
        return;
    }
    
    switch(mPulseState)
    {
        case PULSE_STATE_POSITIVE:
        {
            NSAssert(mUsePath == mHighlightedPath, @"Pulse state is positive, but not using the mHighlightedPath");
            
            if ([mHighlightedPath Finished])
            {
                mPulseState = PULSE_STATE_HIGHLIGHTED;
            }
            
            break;
        }
        
        case PULSE_STATE_NEGATIVE:
        {   
            NSAssert(mUsePath == mHighlightedPath, @"Pulse state is negative, but not using the mHighlightedPath");
            
            if ([mHighlightedPath Finished])
            {
                mPulseState = PULSE_STATE_NORMAL;
                mUsePath = mEnabledPath;
                
                [mEnabledPath SetTime:0.0];
            }
            
            break;
        }
    }
    
    [mUsePath GetValueScalar:&mBlurLevel];
    [mUsePath Update:inTimeStep];
    
    [super Update:inTimeStep];
}

-(void)DrawOrtho
{
    glMatrixMode(GL_MODELVIEW);
    
    float vertex[12] = {    0, 0, 0,
                            0, 1, 0,
                            1, 0, 0,
                            1, 1, 0 };
                            
    float texCoord[8] = {   0, 0,
                            0, 1,
                            1, 0,
                            1, 1  };
                                                                                                                                        
    GLState glState;
    SaveGLState(&glState);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        
    glVertexPointer(3, GL_FLOAT, 0, vertex);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoord);

    glMatrixMode(GL_MODELVIEW);
    
    // We want to multiply the per vertex color with the per fragment texture sample
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    
    glPushMatrix();
    {        
        // Draw background blur layers
        glPushMatrix();
        {                
            int count = [mBlurLayers count];
            
            float stepAmount = 1.0 / (float)count;
            float accumulatedStep = 1.0;
            
            if (mParams.mBloomBackground)
            {
                glTranslatef(-BORDER_SIZE, -BORDER_SIZE, 0.0f);
            }
            
            int arrayIndex = 0;
                    
            for (int curTexIndex = 0; curTexIndex < sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH]; curTexIndex++)
            {
                int mask = (1 << (sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH] - curTexIndex - 1));
                
                if ((sDiscardField[mParams.mQuality] & mask) == 0)
                {
                    continue;
                }
                
                glPushMatrix();
                {
                    Texture* curTexture = [mBlurLayers objectAtIndex:arrayIndex];
                    
                    // Every level is scaled double previous one.  So smallest level is
                    // scaled by a factor of 2 ^ (count - 1)
                    glScalef(   curTexture->mGLWidth * pow(2, (sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH] - curTexIndex - 1)),
                                curTexture->mGLHeight * pow(2, (sNumDownsampleLevels[NEON_BUTTON_QUALITY_HIGH] - curTexIndex - 1)),
                                1.0 );
                    
                    accumulatedStep -= stepAmount;
                    
                    float useAlpha = 1.0;

                    if ((accumulatedStep + stepAmount) < mBlurLevel)
                    {
                        useAlpha = mAlpha;
                    }
                    else
                    {
                        float amount = (mBlurLevel - accumulatedStep) / stepAmount;
                        
                        if (amount < 0.0)
                        {
                            amount = 0.0;
                        }
                        
                        useAlpha = amount * mAlpha;
                    }
                    
                    if (useAlpha > 0.0)
                    {
                        glColor4f(1.0, 1.0, 1.0, useAlpha);
                        
                        [curTexture Bind];
                        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
                    }
                }
                glPopMatrix();
                
                arrayIndex++;
            }
        }
        glPopMatrix();

        // Button itself and text don't honor the mBlur value.  They work only on alpha.
        glColor4f(1.0, 1.0, 1.0, mAlpha);

        // Draw button
        glPushMatrix();
        {   
            glScalef(mBaseTexture->mGLWidth, mBaseTexture->mGLHeight, 1.0);

            [mBaseTexture Bind];
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }
        glPopMatrix();
        
        // Draw text (if applicable)
        if (mTextTexture)
        {
            glPushMatrix();
            {
                u32 hAlign = GetHAlignPixels(&mParams.mTextPlacement);
                u32 vAlign = GetVAlignPixels(&mParams.mTextPlacement);
                
                glTranslatef((float)hAlign, (float)vAlign, 0.0);
                glScalef(mTextTexture->mGLWidth, mTextTexture->mGLHeight, 1.0);
                
                [mTextTexture Bind];
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            }
            glPopMatrix();
        }
    }
    glPopMatrix();

    glColor4f(1.0, 1.0, 1.0, 1.0);

    [Texture Unbind];

    RestoreGLState(&glState);
        
    NeonGLError();
}

+(void)InitDefaultParams:(NeonButtonParams*)outParams
{
    outParams->mTexName = NULL;
    outParams->mBackgroundTexName = NULL;
    outParams->mBloomBackground = TRUE;
    outParams->mQuality = NEON_BUTTON_QUALITY_HIGH;
    outParams->mFadeSpeed = BUTTON_DEFAULT_FADE_SPEED;
    
    outParams->mText = NULL;
    outParams->mTextFont = [NSString stringWithString:@"Becker_Black_NF.ttf"];
    outParams->mTextSize = 12;
    outParams->mBorderSize = 0;
    
    SetColor(&outParams->mBorderColor, 0x00, 0x00, 0x00, 0xFF);
    SetColor(&outParams->mTextColor, 0x00, 0x00, 0x00, 0xFF);
    SetAbsolutePlacement(&outParams->mTextPlacement, 0, 0);
}

-(BOOL)HitTestWithPoint:(CGPoint*)inPoint
{
    Texture* useTexture = NULL;
    BOOL buttonTouched = FALSE;

    useTexture = mBaseTexture;

    if ((inPoint->x >= 0) && (inPoint->y >= 0) && (inPoint->x <= useTexture->mWidth) && (inPoint->y <= useTexture->mHeight))
    {
        // If we're inside the bounding box, let's get the texel associated with this point
        
        u32 texel = [useTexture GetTexel:inPoint];
        // Only a touch if we hit a part of the button with non-zero alpha.  Otherwise we clicked a transparent part.
        if ((texel & 0xFF) != 0)
        {
            buttonTouched = TRUE;
        }
    }

    return buttonTouched;
}

-(void)StatusChanged:(UIObjectState)inState
{
    [super StatusChanged:inState];
    
    switch(inState)
    {
        case UI_OBJECT_STATE_HIGHLIGHTED:
        {
            [self BuildPositiveHighlightedPath];
            
            mPulseState = PULSE_STATE_POSITIVE;
            mUsePath = mHighlightedPath;
            break;
        }
        
        case UI_OBJECT_STATE_ENABLED:
        {
            if ((mPulseState == PULSE_STATE_POSITIVE) || (mPulseState == PULSE_STATE_HIGHLIGHTED))
            {
                mPulseState = PULSE_STATE_NEGATIVE;
                [self BuildNegativeHighlightedPath];
                
                mUsePath = mHighlightedPath;
            }
            
            break;
        }
    }
}

-(void)BuildEnabledPath
{
    [mEnabledPath AddNodeScalar:0.0 atTime:0.0];
    [mEnabledPath AddNodeScalar:0.0 atTime:BUTTON_IDLE_LEAD_TIME];
    [mEnabledPath AddNodeScalar:BUTTON_IDLE_ACCELERATE_INTENSITY atTime:BUTTON_IDLE_LEAD_TIME + BUTTON_IDLE_SEGMENT_TIME];
    [mEnabledPath AddNodeScalar:BUTTON_IDLE_MAX_INTENSITY atTime:BUTTON_IDLE_LEAD_TIME + 2 * BUTTON_IDLE_SEGMENT_TIME];
    [mEnabledPath AddNodeScalar:BUTTON_IDLE_ACCELERATE_INTENSITY atTime:BUTTON_IDLE_LEAD_TIME + 3 * BUTTON_IDLE_SEGMENT_TIME];
    [mEnabledPath AddNodeScalar:0.0 atTime:BUTTON_IDLE_LEAD_TIME + 4 * BUTTON_IDLE_SEGMENT_TIME];
    
    [mEnabledPath SetPeriodic:TRUE];
}

-(void)BuildPositiveHighlightedPath
{
    float curVal;
    
    [mUsePath GetValueScalar:&curVal];
    
    [mHighlightedPath Reset];
    [mHighlightedPath AddNodeScalar:curVal atIndex:0 withSpeed:BUTTON_HIGHLIGHT_SPEED];
    [mHighlightedPath AddNodeScalar:1.0 atIndex:1 withSpeed:BUTTON_HIGHLIGHT_SPEED];
}

-(void)BuildNegativeHighlightedPath
{
    float curVal;
    
    [mUsePath GetValueScalar:&curVal];
    
    [mHighlightedPath Reset];
    [mHighlightedPath AddNodeScalar:1.0 atIndex:0 withSpeed:BUTTON_HIGHLIGHT_SPEED];
    [mHighlightedPath AddNodeScalar:1.0 atIndex:1 withSpeed:BUTTON_HIGHLIGHT_SPEED];
    [mHighlightedPath AddNodeScalar:0.0 atIndex:2 withSpeed:BUTTON_HIGHLIGHT_SPEED];
}

-(void)CalculateTextPlacement
{
    u32 outerWidth = mBackgroundTexture->mWidth;
    u32 outerHeight = mBackgroundTexture->mHeight;
    
    u32 innerWidth = mTextEndX - mTextStartX;
    u32 innerHeight = mTextEndY - mTextStartY;
    
    CalculatePlacement(&mParams.mTextPlacement, outerWidth, outerHeight, innerWidth, innerHeight);
}

-(u32)GetWidth
{
    return mBackgroundTexture->mWidth;
}

-(u32)GetHeight
{
    return mBackgroundTexture->mHeight;
}


@end