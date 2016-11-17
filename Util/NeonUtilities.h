//
//  NeonUtilities.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#ifdef __cplusplus
extern "C"
{
#endif

#import "NeonMath.h"

#define MIN_FRAMEBUFFER_DIMENSION   (16)

void NeonGLError();
void DumpPPM(unsigned int* inImageData, const char* inFileName, int inWidth, int inHeight);
void DumpPPMAlpha(unsigned char* inImageData, const char* inFileName, int inWidth, int inHeight);

typedef struct
{
    GLint   mViewport[4];
    GLint   mFB;
    GLint   mSrcBlend, mDestBlend;
    GLint   mBlendEnabled;
    GLint   mDepthTestEnabled;
    GLint   mCullingEnabled;
    GLint   mLightingEnabled;
    GLint   mTextureEnabled;
    GLint   mTextureBinding;
    GLint   mTexEnvMode;
    GLint   mMatrixMode;
    GLint   mVertexArrayEnabled, mColorArrayEnabled, mTexCoordArrayEnabled, mNormalArrayEnabled;
} GLState;

void SaveGLState(GLState* inState);
void RestoreGLState(GLState* inState);

u32  GetNumChannels(GLenum inFormat);
u32  GetTypeSize(GLenum inFormat);

void VirtualToScreenRect(Rect2D* inVirtual, Rect2D* outScreen);

u32  GetScreenVirtualWidth();
u32  GetScreenVirtualHeight();

u32  GetScreenAbsoluteWidth();
u32  GetScreenAbsoluteHeight();

void SaveScreen(NSString* inFilename);
void SaveScreenRect(NSString* inFilename, int inWidth, int inHeight);
void SaveScreenRectMemory(unsigned char* inBuffer, int inWidth, int inHeight);

#ifdef __cplusplus
}
#endif