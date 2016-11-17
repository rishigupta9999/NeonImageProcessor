//
//  ResourceManager.m
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.

#import "ResourceManager.h"
#import "BigFile.h"

@implementation FileNode
-(void)dealloc
{
    [mAssetName release];
    [mPath release];
    
    [super dealloc];
}
@end

@implementation ResourceNode

-(void)Reset
{
    mPath = NULL;
    
    mReferenceCount = 0;
    mHandle = 0;
    mResourceType = RESOURCETYPE_INVALID;
    
    mData = 0;
    mMetadata = 0;
}

-(void)dealloc
{
    [mPath release];
    [mHandle release];
    [mData release];
    [mMetadata release];

    [super dealloc];
}

@end

@implementation ResourceManager

static ResourceManager* sInstance = NULL;

static const int INITIAL_NUM_FILENODES = 10;
static const int INITIAL_NUM_FREEHANDLES = 0;
static const int INITIAL_HANDLE = 0;

+(void)CreateInstance
{
    sInstance = [ResourceManager alloc];
    
    [sInstance Init];
}

+(void)DestroyInstance
{
    [sInstance Term];
    
    [sInstance release];
    
    sInstance = NULL;
}

+(ResourceManager*)GetInstance
{
    return sInstance;
}

-(void)Init
{
    mFileNodes = [[NSMutableArray alloc] initWithCapacity:INITIAL_NUM_FILENODES];
    mResourceNodes = [[NSMutableArray alloc] initWithCapacity:INITIAL_NUM_FILENODES];
    mFreeHandles = [[NSMutableArray alloc] initWithCapacity:INITIAL_NUM_FREEHANDLES];
    mApplicationResourcePath = [[NSString alloc] initWithString:[[NSBundle mainBundle] resourcePath]];
    
    mCurHandle = INITIAL_HANDLE;
    
#if TARGET_OS_IPHONE 
    [self GenerateFileNodes];
#endif
}

-(void)Term
{
    [mResourceNodes release];
    [mFreeHandles release];
    [mApplicationResourcePath release];
    [mFileNodes release];
}

-(void)GenerateFileNodes
{
    NSString* appPath = [[NSBundle mainBundle] bundlePath];
    NSString* dataPath = [appPath stringByAppendingPathComponent:@"Data"];
    
    NSDirectoryEnumerator* directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:dataPath];
    NSAssert(directoryEnumerator != NULL, @"Game data not found, are the paths set up correctly?\n");
    
    NSString* fileName = NULL;
    
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:dataPath];
    
    do
    {
        fileName = [directoryEnumerator nextObject];
        
        if (fileName != NULL)
        {
            BOOL directory = FALSE;
            
            [[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&directory];
            
            if (!directory)
            {
                FileNode* curNode = [FileNode alloc];
                
                curNode->mPath = [[NSString alloc] initWithString:fileName];
                curNode->mAssetName = [[NSString alloc] initWithString:[fileName lastPathComponent]];
                
                [mFileNodes addObject:curNode];
                
                [curNode release];
            }
        }
    }
    while (fileName != NULL);
}

-(NSNumber*)LoadAssetWithPath:(NSString*)inPath
{
    // Check and see if this asset exists in the resource list
    
    NSNumber* retHandle = NULL;
    
    [self SetWorkingDirectory];
    
    ResourceNode* resourceNode = [self FindResourceWithPath:inPath];
    
    if (resourceNode != NULL)
    {
        resourceNode->mReferenceCount++;
        retHandle = resourceNode->mHandle;
    }
    else
    {
        ResourceNode* resourceNode = [self CreateResourceNodeWithPath:inPath];
        
        [self LoadData:resourceNode];
        
        retHandle = resourceNode->mHandle;
    }
    
    return retHandle;
}

-(NSNumber*)LoadAssetWithName:(NSString*)inName
{
    return [self InternalLoadAssetWithName:inName loadType:LOADTYPE_ALLOC];
}

-(NSNumber*)LoadMappedAssetWithName:(NSString*)inName
{
    return [self InternalLoadAssetWithName:inName loadType:LOADTYPE_MMAP];
}

-(NSNumber*)InternalLoadAssetWithName:(NSString*)inName loadType:(LoadType)inLoadType
{
    // Check and see if this asset exists in the resource list
    
    NSNumber* retHandle = NULL;
        
    ResourceNode* resourceNode = [self FindResourceWithName:inName];
    
    if (resourceNode != NULL)
    {
        resourceNode->mReferenceCount++;
        retHandle = resourceNode->mHandle;
    }
    else
    {
        FileNode* fileNode = [self FindFileWithName:inName];
        NSAssert1(fileNode != NULL, @"Could not find file %s.  No data will be loaded here.\n", [inName UTF8String]);
        
        if (fileNode != NULL)
        {
            NSMutableString* tempString = [NSMutableString stringWithString:@"Data/"];
            [tempString appendString:fileNode->mPath];
            
            ResourceNode* resourceNode = [self CreateResourceNodeWithPath:tempString];
            
            [self LoadData:resourceNode];
            
            retHandle = resourceNode->mHandle;
        }
    }
    
    return retHandle;
}

-(NSString*)FindAssetWithName:(NSString*)inName
{
    FileNode* fileNode = [self FindFileWithName:inName];
    NSAssert1(fileNode != NULL, @"Could not find file %s.", inName);
    
    NSString* retString = [NSString stringWithString:fileNode->mPath];
    
    return retString;
}

-(ResourceNode*)CreateResourceNodeWithPath:(NSString*)inPath
{
    ResourceNode* resourceNode = [ResourceNode alloc];
    
    resourceNode->mPath = [[NSString alloc] initWithString:inPath];
    resourceNode->mReferenceCount = 1;
    resourceNode->mMetadata = NULL;
    
    int numFreeHandles = [mFreeHandles count];
    
    if (numFreeHandles != 0)
    {
        resourceNode->mHandle = [mFreeHandles objectAtIndex:(numFreeHandles - 1)];
        [resourceNode->mHandle retain];
        
        [mFreeHandles removeObjectAtIndex:(numFreeHandles - 1)];
    }
    else
    {
        resourceNode->mHandle = [[NSNumber alloc] initWithInt:mCurHandle];
        mCurHandle++;
        
        if (mCurHandle == 0)
        {
            NSAssert(false, @"Out of handle space.  Why do we have so many assets loaded?");
        }
    }
    
    [mResourceNodes addObject:resourceNode];
                
    [resourceNode release];
    
    return resourceNode;
}

-(void)UnloadAssetWithHandle:(NSNumber*)inHandle
{
    ResourceNode* resourceNode = [self FindResourceWithHandle:inHandle];
    NSAssert(resourceNode != NULL, @"Could not find resource\n");
    
    if (resourceNode != NULL)
    {
        resourceNode->mReferenceCount--;
        
        NSAssert(resourceNode->mReferenceCount >= 0, @"Reference count has dropped below zero.");
        
        if (resourceNode->mReferenceCount == 0)
        {
            // Store off the handle for future use, and remove the resource node's reference to it
            [mFreeHandles addObject:resourceNode->mHandle];
            
            // Get rid of the defunct resource node.  The resource is no longer loaded.
            [mResourceNodes removeObject:resourceNode];
        }
    }
}

-(ResourceNode*)FindResourceWithPath:(NSString*)inPath
{
    ResourceNode* retNode = NULL;
    
    int numResources = [mResourceNodes count];

    for (int i = 0; i < numResources; i++)
    {
        ResourceNode* curResource = [mResourceNodes objectAtIndex:i];
        
        if ([inPath compare:curResource->mPath] == NSOrderedSame)
        {
            retNode = curResource;
            break;
        }
    }

    return retNode;
}

-(ResourceNode*)FindResourceWithHandle:(NSNumber*)inHandle
{
    ResourceNode* retNode = NULL;
    
    int numResources = [mResourceNodes count];

    for (int i = 0; i < numResources; i++)
    {
        ResourceNode* curResource = [mResourceNodes objectAtIndex:i];
        
        if ([inHandle isEqualToValue:curResource->mHandle])
        {
            retNode = curResource;
            break;
        }
    }

    return retNode;
}

-(ResourceNode*)FindResourceWithName:(NSString*)inPath
{
    ResourceNode* retNode = NULL;
    
    int numResources = [mResourceNodes count];

    for (int i = 0; i < numResources; i++)
    {
        ResourceNode* curResource = [mResourceNodes objectAtIndex:i];
        
        if ([inPath compare:[curResource->mPath lastPathComponent]] == NSOrderedSame)
        {
            retNode = curResource;
            break;
        }
    }

    return retNode;
}

-(void)LoadData:(ResourceNode*)inResourceNode
{
#if TARGET_OS_IPHONE
    NSMutableString* loadPath = [[[NSMutableString alloc] initWithString:mApplicationResourcePath] autorelease];
    
    [loadPath appendString:@"/"];
    [loadPath appendString:(inResourceNode->mPath)];
#else
    NSString* loadPath = inResourceNode->mPath;
#endif
    
    inResourceNode->mData = [[[NSFileManager defaultManager] contentsAtPath:loadPath] retain];
    
    NSString* fileExtension = [inResourceNode->mPath pathExtension];

    [self CreateMetadataForNode:inResourceNode withExtension:fileExtension];

    NSAssert(inResourceNode->mData != NULL, @"Could not find file.");
}

-(NSData*)GetDataForHandle:(NSNumber*)inHandle
{
    NSData* retData = NULL;
    
    ResourceNode* resource = [self FindResourceWithHandle:inHandle];
    NSAssert(resource != NULL, @"Invalid resource handle was specified");
    
    if (resource != NULL)
    {
        retData = resource->mData;
    }
    
    return retData;
}

-(void)SetWorkingDirectory
{
    NSString* appPath = [[NSBundle mainBundle] bundlePath];
    NSString* dataPath = [appPath stringByAppendingPathComponent:@"Data"];
    
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:dataPath];

}

-(FileNode*)FindFileWithName:(NSString*)inName
{
    FileNode* retNode = NULL;
    
    int numFiles = [mFileNodes count];

    for (int i = 0; i < numFiles; i++)
    {
        FileNode* curFile = [mFileNodes objectAtIndex:i];
        
        if ([inName caseInsensitiveCompare:curFile->mAssetName] == NSOrderedSame)
        {
            retNode = curFile;
            break;
        }
    }

    return retNode;
}

-(void)CreateMetadataForNode:(ResourceNode*)inResourceNode withExtension:(NSString*)inFileExtension
{
    inResourceNode->mMetadata = NULL;
    inResourceNode->mResourceType = RESOURCETYPE_STANDARD;
    
    if ([inFileExtension compare:@"fag"] == NSOrderedSame)
    {
        inResourceNode->mMetadata = [[BigFile alloc] InitWithData:inResourceNode->mData];
        inResourceNode->mResourceType = RESOURCETYPE_BIGFILE;
    }
}

-(BigFile*)GetBigFile:(NSNumber*)inHandle
{
    ResourceNode* node = [self FindResourceWithHandle:inHandle];
    BigFile* retVal = NULL;
    
    if ((node != NULL) && (node->mResourceType == RESOURCETYPE_BIGFILE))
    {
        retVal = (BigFile*)node->mMetadata;
    }
    
    return retVal;
}

@end