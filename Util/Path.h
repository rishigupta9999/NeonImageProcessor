//
//  Path.h
//  Neon21
//
//  Copyright Neon Games 2009. All rights reserved.
//

#import "NeonMath.h"

typedef enum
{
    PATH_TYPE_TIME,
    PATH_TYPE_SPEED,
    PATH_TYPE_INVALID
} PathType;

typedef enum
{
    PATH_INTERPOLATION_LINEAR,
    PATH_INTERPOLATION_BEZIER,
    PATH_INTERPOLATION_INVALID
} PathInterpolationMethod;

typedef struct
{
    PathInterpolationMethod mInterpolationMethod;
    float                   mTime;
    
    union
    {
        struct
        {
            Vector2         mInTangent;
            Vector2         mOutTangent;
        } mBezierData;
        
        struct
        {
            float           mPad[4];
        } mLinearData;
        
    } mPathTypeSpecificData;

} PathNodeParams;

@interface PathNode : NSObject
{
    @public
        Vector4                 mValue;
        CFTimeInterval          mTime;
        float                   mSpeed;
        
        PathInterpolationMethod mInterpolationMethod;
}

@end

@interface BezierPathNode : PathNode
{
    @public
        Vector2                 mInTangent;
        Vector2                 mOutTangent;
}

@end

@class Path;

typedef enum
{
    // For non-periodic paths, this event is sent when a path finishes
    PATH_EVENT_COMPLETED,
    
    // For periodic paths, this event is sent when a path finishes a cycle
    PATH_EVENT_CYCLED,
    
    PATH_EVENT_NUM
} PathEvent;

@protocol PathCallback

-(void)PathEvent:(PathEvent)inEvent withPath:(Path*)inPath userData:(u32)inData;

@end

@interface Path : NSObject
{
    NSMutableArray* mNodes;
    CFTimeInterval  mTime;
    
    u32             mLastNodeVisited;
    CFTimeInterval  mVisitTime;
    
    PathType                mType;
    PathInterpolationMethod mInterpolationMethod;
    BOOL                    mPeriodic;
    
    BOOL            mDispatchedFinishedEvent;
    
    CFTimeInterval  mFinalTime;
    
    NSObject<PathCallback>*     mCallback;
    u32                         mUserData;
}

// Public API

-(Path*)Init;
-(void)Reset;
+(void)InitPathNodeParams:(PathNodeParams*)outParams;

// Create time based nodes
-(void)AddNodeVec4:(Vector4*)inValue atTime:(CFTimeInterval)inTime;
-(void)AddNodeVec3:(Vector3*)inValue atTime:(CFTimeInterval)inTime;
-(void)AddNodeScalar:(float)inValue atTime:(CFTimeInterval)inTime;

-(void)AddNodeVec4:(Vector4*)inValue withParams:(PathNodeParams*)inParams;
-(void)AddNodeVec3:(Vector3*)inValue withParams:(PathNodeParams*)inParams;
-(void)AddNodeScalar:(float)inValue withParams:(PathNodeParams*)inParams;

// Create velocity based nodes
-(void)AddNodeVec4:(Vector4*)inValue atIndex:(u32)inIndex withSpeed:(float)inSpeed;
-(void)AddNodeVec3:(Vector3*)inValue atIndex:(u32)inIndex withSpeed:(float)inSpeed;
-(void)AddNodeScalar:(float)inValue atIndex:(u32)inIndex withSpeed:(float)inSpeed;

-(void)SetPeriodic:(BOOL)inPeriodic;
-(void)SetTime:(CFTimeInterval)inTime;

-(u32)GetUserData;
-(void)SetUserData:(u32)inUserData;
-(void)SetCallback:(NSObject<PathCallback>*)inCallback withData:(u32)inUserData;

-(CFTimeInterval)GetFinalTime;
-(void)GetFinalValue:(Vector4*)outFinalValue;

-(BOOL)Finished;

-(void)Update:(CFTimeInterval)inTimeStep;

// Private API - Outside classes should not use these
-(void)GetValueVec4:(Vector4*)outInterpolatedValue;
-(void)GetValueVec3:(Vector3*)outInterpolatedValue;
-(void)GetValueScalar:(float*)outInterpolatedValue;

-(void)GetBoundingNodes:(CFTimeInterval)inTime Lower:(PathNode**)outLower Upper:(PathNode**)outUpper;

-(void)GetValueVec4Time:(Vector4*)outInterpolatedValue;
-(void)GetValueVec4Speed:(Vector4*)outInterpolatedValue;

-(void)DebugDumpNodes;

-(void)DispatchEvent:(PathEvent)inEvent;

@end