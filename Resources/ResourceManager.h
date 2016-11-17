//
//  ResourceManager.h
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

typedef enum
{
    LOADTYPE_ALLOC,
    LOADTYPE_MMAP
} LoadType;

typedef enum
{
    RESOURCETYPE_STANDARD,
    RESOURCETYPE_BIGFILE,
    RESOURCETYPE_INVALID
} ResourceType;

@class BigFile;

@interface ResourceNode : NSObject
{
    @public
        NSString*       mPath;
        int             mReferenceCount;
        NSNumber*       mHandle;
        ResourceType    mResourceType;
        
        NSData*         mData;
        NSObject*       mMetadata;
};

-(void)Reset;
@end

@interface FileNode : NSObject
{
    @public
        NSString*   mAssetName;
        NSString*   mPath;
}

@end

@interface ResourceManager : NSObject
{
    @private
        NSMutableArray*  mFileNodes;
        NSMutableArray*  mResourceNodes;
        NSMutableArray*  mFreeHandles;
        
        NSString*        mApplicationResourcePath;
        
        int              mCurHandle;
}

// Class methods that manage creation and access
+(void)CreateInstance;
+(void)DestroyInstance;
+(ResourceManager*)GetInstance;

// Initialization and Shutdown.  Must be called explicitly once.
-(void)Init;
-(void)Term;

// Asset loading functions, these are safe - use these freely.
-(NSNumber*)LoadAssetWithPath:(NSString*)inPath;
-(NSNumber*)LoadAssetWithName:(NSString*)inName;
-(NSNumber*)LoadMappedAssetWithName:(NSString*)inName;
-(NSString*)FindAssetWithName:(NSString*)inName;
-(void)UnloadAssetWithHandle:(NSNumber*)inHandle;
-(NSData*)GetDataForHandle:(NSNumber*)inHandle;

// You should not need to call these, but they are there and should be relatively safe.
-(ResourceNode*)FindResourceWithPath:(NSString*)inPath;
-(ResourceNode*)FindResourceWithHandle:(NSNumber*)inHandle;
-(ResourceNode*)FindResourceWithName:(NSString*)inName;
-(FileNode*)FindFileWithName:(NSString*)inName;

// Internally used functions.  Don't call these externally, can be dangerous.

-(ResourceNode*)CreateResourceNodeWithPath:(NSString*)inPath;
-(NSNumber*)InternalLoadAssetWithName:(NSString*)inName loadType:(LoadType)inLoadType;
-(void)CreateMetadataForNode:(ResourceNode*)inResourceNode withExtension:(NSString*)inFileExtension;
-(BigFile*)GetBigFile:(NSNumber*)inHandle;

-(void)LoadData:(ResourceNode*)inResourceNode;

-(void)SetWorkingDirectory;
-(void)GenerateFileNodes;

@end