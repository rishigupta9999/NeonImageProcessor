//
//  Queue.h
//  Neon21
//
//  Copyright Neon Games 2008. All rights reserved.
//

#import "Queue.h"

@implementation Queue

-(Queue*)Init
{
    mArray = [[NSMutableArray alloc] initWithCapacity:5];
	
	return self;
}

-(void)dealloc
{
    [super dealloc];
    
    [mArray release];
}

-(void)Enqueue:(NSObject*)inObject
{
    [mArray addObject:inObject];
}

-(NSObject*)Dequeue
{
    NSObject* retVal = NULL;
	
	if ([mArray count] > 0)
	{
		retVal = [mArray objectAtIndex:0];
		
		if (retVal != NULL)
		{
			[mArray removeObjectAtIndex:0];
		}
	}
    
    return retVal;
}

@end