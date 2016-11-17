//
//  NeonMath.m
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#include "NeonMath.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdbool.h>
#include <assert.h>

#ifdef __cplusplus
extern "C"
{
#endif

const float EPSILON = 0.001;

#pragma mark Scalar

float DegreesToRadians(float inDegrees)
{
    return (inDegrees * M_PI) / 180.0f;
}

float RadiansToDegrees(float inRadians)
{
    return inRadians * (180.0f / M_PI);
}

float ClampFloat(float inValue, float inLower, float inUpper)
{
    float retVal = inValue;
    
    if (inValue < inLower)
    {
        retVal = inLower;
    }
    else if (inValue > inUpper)
    {
        retVal = inUpper;
    }
    
    return retVal;
}

int ClampInt(int inValue, int inLower, int inUpper)
{
    int retVal = inValue;
    
    if (inValue < inLower)
    {
        retVal = inLower;
    }
    else if (inValue > inUpper)
    {
        retVal = inUpper;
    }
    
    return retVal;
}

float LClampFloat(float inValue, float inLower)
{
    float retVal = inValue;
    
    if (inValue < inLower)
    {
        retVal = inLower;
    }
    
    return retVal;
}

float FloorToMultipleFloat(float inValue, float inMultiplier)
{
    float divisor = (float)((int)(inValue / inMultiplier));
    
    return divisor * inMultiplier;
}

bool RangesIntersect(Range* inLeft, Range* inRight)
{
    // Case where the left range is entirely contained within the right range
    //
    // Left Range:           -------
    // Right Range:      ---------------
    if ((inLeft->mStart >= inRight->mStart) && ((inLeft->mStart + inLeft->mLength) <= (inRight->mStart + inRight->mLength)))
    {
        return true;
    }
    // Case where right range is entirely contained within the left range
    //
    // Left Range:       -----------------
    // Right Range:         --------
    else if ((inLeft->mStart <= inRight->mStart) && ((inLeft->mStart + inLeft->mLength) >= (inRight->mStart + inRight->mLength)))
    {
        return true;
    }
    // Case where the left range is to the left, but overlaps with the right range
    //
    // Left Range:      ---------
    // Right Range:         ----------
    else if ((inLeft->mStart <= inRight->mStart) && ((inLeft->mStart + inLeft->mLength) <= (inRight->mStart + inRight->mLength)))
    {
        return true;
    }
    // Case where the left range is to the right, but overlaps with the right range
    //
    // Left Range :          ----------
    // Right Range:      ---------
    else if ((inLeft->mStart >= inRight->mStart) && (inLeft->mStart <= (inRight->mStart + inRight->mLength)))
    {
        return true;
    }
    
    return false;
}

int  RoundUpPOT(int inValue)
{
    float logVal = log2f((float)inValue);
    int exponent = (int)ceilf(logVal);
    return pow(2, exponent);
}

int  RoundDownPOT(int inValue)
{
    float logVal = log2f((float)inValue);
    int exponent = (int)floorf(logVal);
    return pow(2, exponent);
}

double Sinc(double x)
{
    if (x == 0.0)
    {
        return 1.0;
    }
    
    return sin(M_PI * x) / (M_PI * x);
}

double Bessel0(double x)
{
    const double EPSILON_RATIO = 1E-16;
    double xh, sum, pow, ds;

    xh = 0.5 * x;
    sum = 1.0;
    pow = 1.0;
    ds = 1.0;

    int k = 0;
    while (ds > sum * EPSILON_RATIO)
    {
        k++;
        pow *= (xh / k);
        ds = pow * pow;
        sum = sum + ds;
    }

    return sum;
}

double Kaiser(double alpha, double half_width, double x)
{
    double ratio = (x / half_width);
    return Bessel0(alpha * sqrt(1 - ratio * ratio)) / Bessel0(alpha);
}

#pragma mark Vector

void Set(Vector3* inVector, float inX, float inY, float inZ)
{
    inVector->mVector[x] = inX;
    inVector->mVector[y] = inY;
    inVector->mVector[z] = inZ;
}

void SetVec2(Vector2* inVector, float inX, float inY)
{
    inVector->mVector[x] = inX;
    inVector->mVector[y] = inY;
}

void SetVec4(Vector4* inVector, float inX, float inY, float inZ, float inW)
{
    inVector->mVector[x] = inX;
    inVector->mVector[y] = inY;
    inVector->mVector[z] = inZ;
    inVector->mVector[w] = inW;
}

Vector4* SetVec4From3(Vector4* inVector, Vector3* inVector3, float inW)
{
    inVector->mVector[x] = inVector3->mVector[x];
    inVector->mVector[y] = inVector3->mVector[y];
    inVector->mVector[z] = inVector3->mVector[z];
    inVector->mVector[w] = inW;
    
    return inVector;
}

Vector3* SetVec3From4(Vector3* inVector, Vector4* inVector4)
{
    inVector->mVector[x] = inVector4->mVector[x];
    inVector->mVector[y] = inVector4->mVector[y];
    inVector->mVector[z] = inVector4->mVector[z];

    return inVector;
}

void CloneVec4(Vector4* inSource, Vector4* inDest)
{
    memcpy(inDest->mVector, inSource->mVector, sizeof(float) * 4);
}

void CloneVec3(Vector3* inSource, Vector3* inDest)
{
    memcpy(inDest->mVector, inSource->mVector, sizeof(float) * 3);
}

void CloneVec2(Vector2* inSource, Vector2* inDest)
{
    memcpy(inDest->mVector, inSource->mVector, sizeof(float) * 2);
}

void Add3(Vector3* inFirst, Vector3* inSecond, Vector3* outResult)
{
    outResult->mVector[x] = inFirst->mVector[x] + inSecond->mVector[x];
    outResult->mVector[y] = inFirst->mVector[y] + inSecond->mVector[y];
    outResult->mVector[z] = inFirst->mVector[z] + inSecond->mVector[z];
}

void Add4(Vector4* inFirst, Vector4* inSecond, Vector4* outResult)
{
    outResult->mVector[x] = inFirst->mVector[x] + inSecond->mVector[x];
    outResult->mVector[y] = inFirst->mVector[y] + inSecond->mVector[y];
    outResult->mVector[z] = inFirst->mVector[z] + inSecond->mVector[z];
    outResult->mVector[w] = inFirst->mVector[w] + inSecond->mVector[w];
}

void Sub2(Vector2* inFirst, Vector2* inSecond, Vector2* outResult)
{
    outResult->mVector[x] = inFirst->mVector[x] - inSecond->mVector[x];
    outResult->mVector[y] = inFirst->mVector[y] - inSecond->mVector[y];
}

void Sub3(Vector3* inFirst, Vector3* inSecond, Vector3* outResult)
{
    outResult->mVector[x] = inFirst->mVector[x] - inSecond->mVector[x];
    outResult->mVector[y] = inFirst->mVector[y] - inSecond->mVector[y];
    outResult->mVector[z] = inFirst->mVector[z] - inSecond->mVector[z];
}

void Sub4(Vector4* inFirst, Vector4* inSecond, Vector4* outResult)
{
    outResult->mVector[x] = inFirst->mVector[x] - inSecond->mVector[x];
    outResult->mVector[y] = inFirst->mVector[y] - inSecond->mVector[y];
    outResult->mVector[z] = inFirst->mVector[z] - inSecond->mVector[z];
    outResult->mVector[w] = inFirst->mVector[w] - inSecond->mVector[w];
}

void Scale4(Vector4* inVec, float inScale)
{
    inVec->mVector[x] *= inScale;
    inVec->mVector[y] *= inScale;
    inVec->mVector[z] *= inScale;
    inVec->mVector[w] *= inScale;
}

float Length2(Vector2* inVector)
{
    return sqrt((inVector->mVector[x] * inVector->mVector[x]) + (inVector->mVector[y] * inVector->mVector[y]));
}

void Mul3(float inMultiplier, Vector3* inOutVector)
{
    inOutVector->mVector[x] *= inMultiplier;
    inOutVector->mVector[y] *= inMultiplier;
    inOutVector->mVector[z] *= inMultiplier;
}

void Normalize3(Vector3* inOutVector)
{
    float magnitudeSquared =   (inOutVector->mVector[x] * inOutVector->mVector[x]) + 
                                (inOutVector->mVector[y] * inOutVector->mVector[y]) +
                                (inOutVector->mVector[z] * inOutVector->mVector[z]);
                                
    float magnitude = sqrt(magnitudeSquared);
    
    inOutVector->mVector[x] = inOutVector->mVector[x] / magnitude;
    inOutVector->mVector[y] = inOutVector->mVector[y] / magnitude;
    inOutVector->mVector[z] = inOutVector->mVector[z] / magnitude;
}

void Normalize4(Vector4* inOutVector)
{
    float length = Length4(inOutVector);
    
    inOutVector->mVector[x] /= length;
    inOutVector->mVector[y] /= length;
    inOutVector->mVector[z] /= length;
    inOutVector->mVector[w] /= length;
}

void Cross3(Vector3* inFirst, Vector3* inSecond, Vector3* outResult)
{
    outResult->mVector[x] = (inFirst->mVector[y] * inSecond->mVector[z]) - (inFirst->mVector[z] * inSecond->mVector[y]);
    outResult->mVector[y] = (inFirst->mVector[z] * inSecond->mVector[x]) - (inFirst->mVector[x] * inSecond->mVector[z]);
    outResult->mVector[z] = (inFirst->mVector[x] * inSecond->mVector[y]) - (inFirst->mVector[y] * inSecond->mVector[x]);
}

float Dot3(Vector3* inFirst, Vector3* inSecond)
{
    return (inFirst->mVector[x] * inSecond->mVector[x]) + (inFirst->mVector[y] * inSecond->mVector[y]) + (inFirst->mVector[z] * inSecond->mVector[z]);
}

float Length3(Vector3* inVector)
{
    return sqrt( (inVector->mVector[x] * inVector->mVector[x]) +
                 (inVector->mVector[y] * inVector->mVector[y]) +
                 (inVector->mVector[z] * inVector->mVector[z]) );
}

float Length4(Vector4* inVector)
{
    return sqrt( (inVector->mVector[x] * inVector->mVector[x]) +
                 (inVector->mVector[y] * inVector->mVector[y]) +
                 (inVector->mVector[z] * inVector->mVector[z]) +
                 (inVector->mVector[w] * inVector->mVector[2]) );
}

bool Equal(Vector3* inLeft, Vector3* inRight)
{
    return ((inLeft->mVector[x] == inRight->mVector[x]) && (inLeft->mVector[y] == inRight->mVector[y]) && (inLeft->mVector[z] == inRight->mVector[z]));
}

void MidPointVec3(Vector3* inFirst, Vector3* inSecond, Vector3* outMidPoint)
{
    outMidPoint->mVector[x] = (inFirst->mVector[x] + inSecond->mVector[x]) / 2.0f;
    outMidPoint->mVector[y] = (inFirst->mVector[y] + inSecond->mVector[y]) / 2.0f;
    outMidPoint->mVector[z] = (inFirst->mVector[z] + inSecond->mVector[z]) / 2.0f;
}

#pragma mark Matrix

void CloneMatrix44(Matrix44* inSrc, Matrix44* inDest)
{
    memcpy(inDest->mMatrix, inSrc->mMatrix, (sizeof(float) * 16));
}

void SetIdentity(Matrix44* inMatrix)
{
    memset(inMatrix, 0, sizeof(Matrix44));
    
    inMatrix->mMatrix[0] = 1.0f;
    inMatrix->mMatrix[5] = 1.0f;
    inMatrix->mMatrix[10] = 1.0f;
    inMatrix->mMatrix[15] = 1.0f;
}

void Transpose(Matrix44* inMatrix)
{
    Matrix44 transpose;
    
    transpose.mMatrix[0] = inMatrix->mMatrix[0];
    transpose.mMatrix[1] = inMatrix->mMatrix[4];
    transpose.mMatrix[2] = inMatrix->mMatrix[8];
    transpose.mMatrix[3] = inMatrix->mMatrix[12];
    
    transpose.mMatrix[4] = inMatrix->mMatrix[1];
    transpose.mMatrix[5] = inMatrix->mMatrix[5];
    transpose.mMatrix[6] = inMatrix->mMatrix[9];
    transpose.mMatrix[7] = inMatrix->mMatrix[13];
    
    transpose.mMatrix[8] = inMatrix->mMatrix[2];
    transpose.mMatrix[9] = inMatrix->mMatrix[6];
    transpose.mMatrix[10] = inMatrix->mMatrix[10];
    transpose.mMatrix[11] = inMatrix->mMatrix[14];
    
    transpose.mMatrix[12] = inMatrix->mMatrix[3];
    transpose.mMatrix[13] = inMatrix->mMatrix[7];
    transpose.mMatrix[14] = inMatrix->mMatrix[11];
    transpose.mMatrix[15] = inMatrix->mMatrix[15];
    
    memcpy(inMatrix, &transpose, sizeof(Matrix44));
}

void DivideRow(Matrix44* inMatrix, int inRow, float inDivisor)
{
    for (int col = 0; col < 4; col++)
    {
        int index = inRow + (col * 4);
        
        inMatrix->mMatrix[index] /= inDivisor;
    }
}

void SubtractRow(Matrix44* inMatrix, int inLeftRow, int inRightRow, float inRightRowScale, int inDestRow)
{
    for (int col = 0; col < 4; col++)
    {
        int leftIndex = inLeftRow + (col * 4);
        int rightIndex = inRightRow + (col * 4);
        int destIndex = inDestRow + (col * 4);
        
        float left = inMatrix->mMatrix[leftIndex];
        float right = inMatrix->mMatrix[rightIndex];
        
        inMatrix->mMatrix[destIndex] = left - (inRightRowScale * right);
    }
}

void Inverse(Matrix44* inMatrix, Matrix44* outInverse)
{
    Matrix44 sourceMatrix;
    
    SetIdentity(outInverse);
    CloneMatrix44(inMatrix, &sourceMatrix);
    
    for (int col = 0; col < 4; col++)
    {
        float divisor = sourceMatrix.mMatrix[col * 5];
        
        DivideRow(&sourceMatrix, col, divisor);
        DivideRow(outInverse, col, divisor);
        
        for (int row = 0; row < 4; row++)
        {
            if (row != col)
            {
                float scale = sourceMatrix.mMatrix[(col * 4) + row];
                
                SubtractRow(&sourceMatrix, row, col, scale, row);
                SubtractRow(outInverse, row, col, scale, row);
            }
        }
    }
}

void MatrixMultiply(Matrix44* inLeft, Matrix44* inRight, Matrix44* outResult)
{
    Matrix44 tempLeft, tempRight;
    
    CloneMatrix44(inLeft, &tempLeft);
    CloneMatrix44(inRight, &tempRight);
    
    float* l = tempLeft.mMatrix;
    float* r = tempRight.mMatrix;
    
    for (int row = 0; row < 4; row++)
    {
        for (int col = 0; col < 4; col++)
        {
            int writeIndex = (col * 4) + row;
            
            int leftReadBase = row;
            int rightReadBase = (col * 4);
            
            outResult->mMatrix[writeIndex] =    (l[leftReadBase] * r[rightReadBase]) + 
                                                (l[leftReadBase + 4] * r[rightReadBase + 1]) + 
                                                (l[leftReadBase + 8] * r[rightReadBase + 2]) +
                                                (l[leftReadBase + 12] * r[rightReadBase + 3]);
        }
    }
}

void GenerateRotationMatrix(float inAngleDegrees, float inX, float inY, float inZ, Matrix44* outMatrix)
{
    // Formula taken from http://www.opengl.org/documentation/specs/man_pages/hardcopy/GL/html/gl/rotate.html
    // to be consistent with OpenGL spec.
    
    float rX, rY, rZ;
    
    rX = inX;
    rY = inY;
    rZ = inZ;
    
    Vector3 axisRotation;
    Set(&axisRotation, inX, inY, inZ);
    
    Normalize3(&axisRotation);
    
    rX = axisRotation.mVector[x];
    rY = axisRotation.mVector[y];
    rZ = axisRotation.mVector[z];
    
    float c = cos(DegreesToRadians(inAngleDegrees));
    float s = sin(DegreesToRadians(inAngleDegrees));
    
    outMatrix->mMatrix[0] = (rX * rX * (1.0f - c)) + c;
    outMatrix->mMatrix[1] = (rY * rX * (1.0f - c)) + (rZ * s);
    outMatrix->mMatrix[2] = (rX * rZ * (1.0f - c)) - (rY * s);
    outMatrix->mMatrix[3] = 0.0f;
    
    outMatrix->mMatrix[4] = (rX * rY * (1.0f - c)) - (rZ * s);
    outMatrix->mMatrix[5] = (rY * rY * (1.0f - c)) + c;
    outMatrix->mMatrix[6] = (rY * rZ * (1.0f - c)) + (rX * s);
    outMatrix->mMatrix[7] = 0.0f;
    
    outMatrix->mMatrix[8] = (rX * rZ * (1.0f - c)) + (rY * s);
    outMatrix->mMatrix[9] = (rY * rZ * (1.0f - c)) - (rX * s);
    outMatrix->mMatrix[10] = (rZ * rZ * (1.0f - c)) + c;
    outMatrix->mMatrix[11] = 0.0f;
    
    outMatrix->mMatrix[12] = 0.0f;
    outMatrix->mMatrix[13] = 0.0f;
    outMatrix->mMatrix[14] = 0.0f;
    outMatrix->mMatrix[15] = 1.0f;
}

void GenerateTranslationMatrix(float inTranslateX, float inTranslateY, float inTranslateZ, Matrix44* outMatrix)
{
    SetIdentity(outMatrix);
    
    outMatrix->mMatrix[12] = inTranslateX;
    outMatrix->mMatrix[13] = inTranslateY;
    outMatrix->mMatrix[14] = inTranslateZ;
}

void GenerateScaleMatrix(float inScaleX, float inScaleY, float inScaleZ, Matrix44* outMatrix)
{
    SetIdentity(outMatrix);
    
    outMatrix->mMatrix[0] = inScaleX;
    outMatrix->mMatrix[5] = inScaleY;
    outMatrix->mMatrix[10] = inScaleZ;
}

void NeonUnionRect(Rect2D* inBase, Rect2D* inAdd)
{
    inBase->mXMin = min(inBase->mXMin, inAdd->mXMin);
    inBase->mXMax = max(inBase->mXMax, inAdd->mXMax);
    inBase->mYMin = min(inBase->mYMin, inAdd->mYMin);
    inBase->mYMax = max(inBase->mYMax, inAdd->mYMax);
}

void ZeroBoundingBox(BoundingBox* inOutBox)
{
    inOutBox->mMinX = 0.0f;
    inOutBox->mMaxX = 0.0f;
    inOutBox->mMinY = 0.0f;
    inOutBox->mMaxY = 0.0f;
    inOutBox->mMinZ = 0.0f;
    inOutBox->mMaxZ = 0.0f;
}

void CopyBoundingBox(BoundingBox* inSource, BoundingBox* outDest)
{
    outDest->mMinX = inSource->mMinX;
    outDest->mMaxX = inSource->mMaxX;
    
    outDest->mMinY = inSource->mMinY;
    outDest->mMaxY = inSource->mMaxY;
    
    outDest->mMinZ = inSource->mMinZ;
    outDest->mMaxZ = inSource->mMaxZ;
}

void BoxFromBoundingBox(BoundingBox* inBoundingBox, Box* outBox)
{
    outBox->mVertices[0].mVector[x] = inBoundingBox->mMinX;
    outBox->mVertices[0].mVector[y] = inBoundingBox->mMaxY;
    outBox->mVertices[0].mVector[z] = inBoundingBox->mMaxZ;
    
    outBox->mVertices[1].mVector[x] = inBoundingBox->mMaxX;
    outBox->mVertices[1].mVector[y] = inBoundingBox->mMaxY;
    outBox->mVertices[1].mVector[z] = inBoundingBox->mMaxZ;

    outBox->mVertices[2].mVector[x] = inBoundingBox->mMaxX;
    outBox->mVertices[2].mVector[y] = inBoundingBox->mMaxY;
    outBox->mVertices[2].mVector[z] = inBoundingBox->mMinZ;
    
    outBox->mVertices[3].mVector[x] = inBoundingBox->mMinX;
    outBox->mVertices[3].mVector[y] = inBoundingBox->mMaxY;
    outBox->mVertices[3].mVector[z] = inBoundingBox->mMinZ;

    outBox->mVertices[4].mVector[x] = inBoundingBox->mMinX;
    outBox->mVertices[4].mVector[y] = inBoundingBox->mMinY;
    outBox->mVertices[4].mVector[z] = inBoundingBox->mMaxZ;
    
    outBox->mVertices[5].mVector[x] = inBoundingBox->mMaxX;
    outBox->mVertices[5].mVector[y] = inBoundingBox->mMinY;
    outBox->mVertices[5].mVector[z] = inBoundingBox->mMaxZ;
    
    outBox->mVertices[6].mVector[x] = inBoundingBox->mMaxX;
    outBox->mVertices[6].mVector[y] = inBoundingBox->mMinY;
    outBox->mVertices[6].mVector[z] = inBoundingBox->mMinZ;

    outBox->mVertices[7].mVector[x] = inBoundingBox->mMinX;
    outBox->mVertices[7].mVector[y] = inBoundingBox->mMinY;
    outBox->mVertices[7].mVector[z] = inBoundingBox->mMinZ;
}

int TopFaceBoxComparator(const void* inLeft, const void* inRight)
{
    int retVal = 0;
    
    Vector3* left = (Vector3*)inLeft;
    Vector3* right = (Vector3*)inRight;
    
    if (left->mVector[y] < right->mVector[y])
    {
        retVal = 1;
    }
    else if (left->mVector[y] > right->mVector[y])
    {
        retVal = -1;
    }
    
    return retVal;
}

void GetTopCenterForBox(Box* inBox, Vector3* outTopCenter)
{
    Vector3 points[4];
    Box box;
    CloneBox(inBox, &box);
    
    qsort(box.mVertices, 8, sizeof(Vector3), TopFaceBoxComparator);
    
    memcpy(points, box.mVertices, sizeof(float) * 4 * 3);
    FaceCenter(points, outTopCenter);
}

// This function will not work if the world space box isn't aligned to the world axes.
// This is a limitation we can live with for now.
void GetTopFaceForBox(Box* inBox, Face* outFace)
{
    Box box;
    CloneBox(inBox, &box);
    
    qsort(box.mVertices, 8, sizeof(Vector3), TopFaceBoxComparator);

    memcpy(outFace->mVertices, box.mVertices, sizeof(float) * 4 * 3);
}

void CloneBox(Box* inSource, Box* outDest)
{
    memcpy(outDest->mVertices, inSource->mVertices, sizeof(float) * 8 * 3);
}

void FaceCenter(Vector3* inPoints, Vector3* outCenter)
{
    // Find out which points make perpendicular lines.
    
    Vector3* pointOne = NULL;
    Vector3* pointTwo = NULL;
    Vector3* pointThree = NULL;
    
    // Choose an arbitrary root point.
    pointOne = &inPoints[0];
    
    // Find two other points that make perpendicular lines.
    
    bool validPoints = false;
    
    for (int i = 1; i < 4; i++)
    {
        for (int j = 1; j < 4; j++)
        {
            if (i != j)
            {
                Vector3 vectorOne, vectorTwo;
                
                Sub3(&inPoints[i], pointOne, &vectorOne);
                Sub3(&inPoints[j], pointOne, &vectorTwo);
                
                if (abs(Dot3(&vectorOne, &vectorTwo)) < EPSILON)
                {
                    pointTwo = &inPoints[i];
                    pointThree = &inPoints[j];
                    validPoints = true;
                    break;
                }
            }
        }
        
        if (validPoints)
        {
            break;
        }
    }
    
    // If we didn't find perpendicular lines on the box face, the box face points are inconsistent
    assert(validPoints);

    if (validPoints)
    {
        Vector3 midPoint1;
        Vector3 midPoint2;
        
        MidPointVec3(pointOne, pointTwo, &midPoint1);
        MidPointVec3(pointOne, pointThree, &midPoint2);
        
        Vector3 slope1;
        Vector3 slope2;
        
        Sub3(pointOne, pointThree, &slope1);
        Sub3(pointOne, pointTwo, &slope2);
        
        // Bounding box top isn't rectangular.  Double check how this bounding box was generated
        assert(abs(Dot3(&slope1, &slope2)) < EPSILON);
        
        // We now have two lines of the form a + bt and c + dt.  Intersection point
        // is the center of the box.
        
        Vector3 aMinusC;
        Vector3 dMinusB;
        
        Sub3(&midPoint1, &midPoint2, &aMinusC);
        Sub3(&slope2, &slope1, &dMinusB);
        
        float t = 0;
        
        for (int i = 0; i < 3; i++)
        {
            if ((abs(aMinusC.mVector[i]) < EPSILON) && (abs(dMinusB.mVector[i]) < EPSILON))
            {
                continue;
            }
            
            // About to divide by zero.  We have an inconsistent bounding box
            assert(abs(dMinusB.mVector[i]) > EPSILON);
            
            t = aMinusC.mVector[i] / dMinusB.mVector[i];
            break;
        }
        
        Mul3(t, &slope1);
        Add3(&midPoint1, &slope1, outCenter);
    }
}

void FaceExtents(Face* inFace, float* outLeft, float* outRight, float* outTop, float* outBottom)
{
    *outLeft = *outRight = inFace->mVertices[0].mVector[x];
    *outTop = *outBottom = inFace->mVertices[0].mVector[z];
    
    for (int i = 1; i <= 3; i++)
    {
        float vx = inFace->mVertices[i].mVector[x];
        float vz = inFace->mVertices[i].mVector[z];
        
        if (vx < *outLeft)
        {
            *outLeft = vx;
        }
        
        if (vx > *outRight)
        {
            *outRight = vx;
        }
        
        if (vz < *outTop)
        {
            *outTop = vz;
        }
        
        if (vz > *outBottom)
        {
            *outBottom = vz;
        }
    }

}

void LoadFromRowMajorArrayOfArrays(Matrix44* inMatrix, float inData[][4])
{
    LoadFromColMajorArrayOfArrays(inMatrix, inData);
    Transpose(inMatrix);
}

void LoadFromColMajorArrayOfArrays(Matrix44* inMatrix, float inData[][4])
{
    for (int row = 0; row < 4; row++)
    {
        memcpy(&inMatrix->mMatrix[4 * row], &inData[row][0], sizeof(float) * 4);
    }
}

void TransformVector4x3(Matrix44* inTransformationMatrix, Vector3* inSourceVector, Vector4* outDestVector)
{
    Vector4 tempSource;
    
    tempSource.mVector[x] = inSourceVector->mVector[x];
    tempSource.mVector[y] = inSourceVector->mVector[y];
    tempSource.mVector[z] = inSourceVector->mVector[z];
    tempSource.mVector[w] = 1.0f;
    
    TransformVector4x4(inTransformationMatrix, &tempSource, outDestVector);
}

void TransformVector4x4(Matrix44* inTransformationMatrix, Vector4* inSourceVector, Vector4* outDestVector)
{
    for (int row = 0; row < 4; row++)
    {
        float sum = 0;
        
        for (int elem = 0; elem < 4; elem++)
        {
            sum += inTransformationMatrix->mMatrix[row + (elem * 4)] * inSourceVector->mVector[elem];
        }
        
        outDestVector->mVector[row] = sum;
    }
}

#ifdef __cplusplus
}
#endif