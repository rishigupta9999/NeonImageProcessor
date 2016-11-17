//
//  NeonUtilities.m
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "NeonUtilities.h"
#import "NeonTypes.h"
#import "PNGUtilities.h"
#import "png.h"

void NeonGLError()
{
#ifdef NEON_DEBUG
    GLenum texError = glGetError();

    if (texError != 0)
    {
        printf("OpenGL Error %x encountered\n", texError);
    }
#endif
}

void DumpPPM(unsigned int* inImageData, const char* inFileName, int inWidth, int inHeight)
{
    NSString *prevWorkingDir = [[NSFileManager defaultManager] currentDirectoryPath];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:@"/"];
    
    FILE* file = fopen(inFileName, "w");
    
    static const int WRITE_BUFFER_LENGTH = 128;
    char writeBuffer[WRITE_BUFFER_LENGTH];
    
    snprintf(writeBuffer, WRITE_BUFFER_LENGTH, "P3\n%d %d\n255\n", inWidth, inHeight);
    fwrite(writeBuffer, 1, strlen(writeBuffer), file);
    
    for (int row = 0; row < inHeight; row++)
    {
        for (int col = 0; col < inWidth; col++)
        {
            u32 rgbaValue = inImageData[(inWidth * row) + col];
            
            rgbaValue = CFSwapInt32BigToHost(rgbaValue);
            
            u8  r, g, b;
            
            r = (rgbaValue >> 24) & 0xFF;
            g = (rgbaValue >> 16) & 0xFF;
            b = (rgbaValue >> 8) & 0xFF;
            
            snprintf(writeBuffer, WRITE_BUFFER_LENGTH, "%d %d %d\t", r, g, b);
            fwrite(writeBuffer, 1, strlen(writeBuffer), file);
        }
        
        fwrite("\n", 1, 1, file);
    }
            
    fclose(file);
    
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:prevWorkingDir];
}

void DumpPPMAlpha(unsigned char* inImageData, const char* inFileName, int inWidth, int inHeight)
{
    NSString *prevWorkingDir = [[NSFileManager defaultManager] currentDirectoryPath];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:@"/"];
    
    FILE* file = fopen(inFileName, "w");
    
    static const int WRITE_BUFFER_LENGTH = 128;
    char writeBuffer[WRITE_BUFFER_LENGTH];
    
    snprintf(writeBuffer, WRITE_BUFFER_LENGTH, "P3\n%d %d\n255\n", inWidth, inHeight);
    fwrite(writeBuffer, 1, strlen(writeBuffer), file);
    
    for (int row = 0; row < inHeight; row++)
    {
        for (int col = 0; col < inWidth; col++)
        {
            unsigned char alpha = inImageData[(inWidth * row) + col];
            
            snprintf(writeBuffer, WRITE_BUFFER_LENGTH, "%d %d %d\t", alpha, alpha, alpha);
            fwrite(writeBuffer, 1, strlen(writeBuffer), file);
        }
        
        fwrite("\n", 1, 1, file);
    }
            
    fclose(file);
    
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:prevWorkingDir];
}

void SaveGLState(GLState* inState)
{
    glGetIntegerv(GL_VIEWPORT, inState->mViewport);
    
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &inState->mFB);
    
    glGetIntegerv(GL_BLEND_SRC, &inState->mSrcBlend);
    glGetIntegerv(GL_BLEND_DST, &inState->mDestBlend);
    glGetIntegerv(GL_BLEND, &inState->mBlendEnabled);
    
    glGetIntegerv(GL_DEPTH_TEST, &inState->mDepthTestEnabled);
    
    glGetIntegerv(GL_LIGHTING, &inState->mLightingEnabled);
    glGetIntegerv(GL_CULL_FACE, &inState->mCullingEnabled);
    
    glGetIntegerv(GL_TEXTURE_2D, &inState->mTextureEnabled);
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &inState->mTextureBinding);
    glGetTexEnviv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, &inState->mTexEnvMode);
    
    glGetIntegerv(GL_MATRIX_MODE, &inState->mMatrixMode);
    
    glGetIntegerv(GL_VERTEX_ARRAY, &inState->mVertexArrayEnabled);
    glGetIntegerv(GL_COLOR_ARRAY, &inState->mColorArrayEnabled);
    glGetIntegerv(GL_TEXTURE_COORD_ARRAY, &inState->mTexCoordArrayEnabled);
    glGetIntegerv(GL_NORMAL_ARRAY, &inState->mNormalArrayEnabled);
}

static void EnableIfTrue(GLenum inEnum, GLint inEnabled)
{
    if (inEnabled)
    {
        glEnable(inEnum);
    }
    else
    {
        glDisable(inEnum);
    }
}

static void EnableClientStateIfTrue(GLenum inEnum, GLint inEnabled)
{
    if (inEnabled)
    {
        glEnableClientState(inEnum);
    }
    else
    {
        glDisableClientState(inEnum);
    }
}

void RestoreGLState(GLState* inState)
{
    glViewport(inState->mViewport[0], inState->mViewport[1], inState->mViewport[2], inState->mViewport[3]);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, inState->mFB);
    
    glBlendFunc(inState->mSrcBlend, inState->mDestBlend);
    EnableIfTrue(GL_BLEND, inState->mBlendEnabled);

    EnableIfTrue(GL_DEPTH_TEST, inState->mDepthTestEnabled);
    
    EnableIfTrue(GL_TEXTURE_2D, inState->mTextureEnabled);
    glBindTexture(GL_TEXTURE_2D, inState->mTextureBinding);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, inState->mTexEnvMode);
    
    glMatrixMode(inState->mMatrixMode);
    
    EnableClientStateIfTrue(GL_VERTEX_ARRAY, inState->mVertexArrayEnabled);
    EnableClientStateIfTrue(GL_COLOR_ARRAY, inState->mColorArrayEnabled);
    EnableClientStateIfTrue(GL_TEXTURE_COORD_ARRAY, inState->mTexCoordArrayEnabled);
    EnableClientStateIfTrue(GL_NORMAL_ARRAY, inState->mNormalArrayEnabled);
    
    EnableIfTrue(GL_LIGHTING, inState->mLightingEnabled);
    
    EnableIfTrue(GL_CULL_FACE, inState->mCullingEnabled);
    glColor4f(1.0, 1.0, 1.0, 1.0);
    
    NeonGLError();
}

void SaveScreen(NSString* inFilename)
{
    GLint viewport[4];
    
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    int width = viewport[2];
    int height = viewport[3];
    
    u8* buffer = malloc(width * height * 4);
    
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    
    WritePNG(buffer, inFilename, width, height);
    
    free(buffer);
}

void SaveScreenRect(NSString* inFilename, int inWidth, int inHeight)
{
    GLint viewport[4];
    
    glGetIntegerv(GL_VIEWPORT, viewport);
        
    u8* buffer = malloc(inWidth * inHeight * 4);
    
    glReadPixels(0, 0, inWidth, inHeight, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    
    WritePNG(buffer, inFilename, inWidth, inHeight);
    
    free(buffer);
}

void SaveScreenRectMemory(unsigned char* inBuffer, int inWidth, int inHeight)
{
    glReadPixels(0, 0, inWidth, inHeight, GL_RGBA, GL_UNSIGNED_BYTE, inBuffer);
}

u32  GetNumChannels(GLenum inFormat)
{   
    u32 numChannels = 0;
    
    switch(inFormat)
    {
        case GL_RGBA:
        {
            numChannels = 4;
            break;
        }
        
        case GL_RGB:
        {
            numChannels = 3;
            break;
        }
        
        case GL_LUMINANCE_ALPHA:
        {
            numChannels = 2;
            break;
        }
        
        case GL_LUMINANCE:
        case GL_ALPHA:
        {
            numChannels = 1;
            break;
        }
        
        default:
        {
            assert(FALSE);
            break;
        }
    }
    
    return numChannels;
}

u32  GetTypeSize(GLenum inFormat)
{
    u32 size = 0;
    
    switch(inFormat)
    {
        case GL_UNSIGNED_BYTE:
        {
            size = 1;
            break;
        }
        
        case GL_UNSIGNED_SHORT:
        {
            size = 2;
            break;
        }
        
        case GL_FLOAT:
        {
            size = 4;
            break;
        }
        
        default:
        {
            assert(FALSE);
            break;
        }
    }
    
    return size;
}

u32 GetScreenVirtualWidth()
{
    return 480.0f;
}

u32 GetScreenVirtualHeight()
{
    return 320.0f;
}

u32 GetScreenAbsoluteWidth()
{
    return 320.0f;
}

u32 GetScreenAbsoluteHeight()
{
    return 480.0f;
}

void VirtualToScreenRect(Rect2D* inVirtual, Rect2D* outScreen)
{
    outScreen->mYMin = inVirtual->mXMin;
    outScreen->mYMax = inVirtual->mXMax;
    
    outScreen->mXMin = GetScreenVirtualHeight() - inVirtual->mYMax;
    outScreen->mXMax = GetScreenVirtualHeight() - inVirtual->mYMin;
}