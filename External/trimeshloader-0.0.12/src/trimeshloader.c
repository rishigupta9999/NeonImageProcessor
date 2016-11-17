/*
 * Copyright (c) 2007 Gero Mueller <gero.mueller@cloo.de>
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 *    1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 *    2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 *    3. This notice may not be removed or altered from any source
 *    distribution.
 */

#include "trimeshloader.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*----------------------------------------------------------------------------*/
tlTrimesh *tlCreateTrimeshFrom3dsState( tl3dsState *state, unsigned int vertex_format )
{
	tlTrimesh *trimesh = NULL;
	unsigned int i = 0, index = 0;
	float *x = NULL, *y = NULL, *z = NULL;
	float *u = NULL, *v = NULL;
	float *nx = NULL, *ny = NULL, *nz = NULL;
	
	if( state == NULL )
		return NULL;
	
	trimesh = malloc( sizeof(tlTrimesh) );
	
	trimesh->object_count = tl3dsObjectCount( state );
	trimesh->objects = malloc( sizeof(tlObject) * trimesh->object_count );
	for( i = 0; i < trimesh->object_count; i++ )
	{
		unsigned int length = strlen( tl3dsObjectName( state, i ) ) + 1;
		trimesh->objects[i].name = malloc( length );
		memcpy( trimesh->objects[i].name, tl3dsObjectName( state, i ), length );
		trimesh->objects[i].face_index = tl3dsObjectFaceIndex( state, i );
		trimesh->objects[i].face_count = tl3dsObjectFaceCount( state, i );
	}	
	
	trimesh->face_count = tl3dsFaceCount( state );
	trimesh->faces = malloc( sizeof(unsigned short) * trimesh->face_count * 3 );
	for( i = 0; i < trimesh->face_count; i++ )
	{
		unsigned int offset = i * 3;
		tl3dsGetFace( state, i,
			&trimesh->faces[offset],
			&trimesh->faces[offset + 1],
			&trimesh->faces[offset + 2] );
	}

	trimesh->vertex_count = tl3dsVertexCount( state );
	trimesh->vertex_format = vertex_format;
	trimesh->vertex_size = vertex_format & TL_FVF_XYZ ? 3 * sizeof(float) : 0;
	trimesh->vertex_size += vertex_format & TL_FVF_UV ? 2 * sizeof(float) : 0;
	trimesh->vertex_size += vertex_format & TL_FVF_NORMAL ? 3 * sizeof(float) : 0;
	trimesh->vertices = malloc( trimesh->vertex_count * trimesh->vertex_size );
	index = 0;
	for( i = 0; i < trimesh->vertex_count; i++ )
	{
		if( vertex_format & TL_FVF_XYZ )
		{
			x = &trimesh->vertices[index++];
			y = &trimesh->vertices[index++];
			z = &trimesh->vertices[index++];
		}
		
		if( vertex_format & TL_FVF_UV )
		{
			u = &trimesh->vertices[index++];
			v = &trimesh->vertices[index++];
		} 

		if( vertex_format & TL_FVF_NORMAL )
		{
			nx = &trimesh->vertices[index++];
			ny = &trimesh->vertices[index++];
			nz = &trimesh->vertices[index++];
		} 
			
		tl3dsGetVertex( state, i, x, y, z, u, v, nx, ny, nz );
	}
    
    char* texName = tl3dsGetTexName(state);
    
    if (texName != NULL)
    {
        trimesh->tex_name = malloc(strlen(texName) + 1);
        strcpy(trimesh->tex_name, texName);
    }
	
	return trimesh;
}


/*----------------------------------------------------------------------------*/
tlTrimesh *tlLoad3DS( const char *filename, unsigned int vertex_format )
{
	FILE *f = 0;
	tlTrimesh *trimesh = NULL;
	
	if( filename == NULL )
		return NULL;
	
	f = fopen( filename, "r" );
	if( f )
	{
		tl3dsState *state = NULL;

		state = tl3dsCreateState();
		if( state )
		{
			char buffer[1024];
			unsigned int size = 0;
			
			while( !feof( f ) )
			{
				size = (unsigned int) fread( buffer, 1, sizeof(buffer), f );
				tl3dsParse( state, buffer, size, size < sizeof(buffer) ? 1 : 0 );
			}

			trimesh = tlCreateTrimeshFrom3dsState( state, vertex_format );
			
			tl3dsDestroyState( state );
		}
		
		fclose( f );
	}
	
	return trimesh;
}


/*----------------------------------------------------------------------------*/
tlTrimesh *tlCreateTrimeshFromObjState( tlObjState *state, unsigned int vertex_format )
{
	tlTrimesh *trimesh = NULL;
	unsigned int i = 0, index = 0;
	float *x = NULL, *y = NULL, *z = NULL;
	float *u = NULL, *v = NULL;
	float *nx = NULL, *ny = NULL, *nz = NULL;
	
	if( state == NULL )
		return NULL;
	
	trimesh = malloc( sizeof(tlTrimesh) );
	
	
	trimesh->object_count = tlObjObjectCount( state );
	trimesh->objects = malloc( sizeof(tlObject) * trimesh->object_count );
	for( i = 0; i < trimesh->object_count; i++ )
	{
		unsigned int length = strlen( tlObjObjectName( state, i ) ) + 1;
		trimesh->objects[i].name = malloc( length );
		memcpy( trimesh->objects[i].name, tlObjObjectName( state, i ), length );
		trimesh->objects[i].face_index = tlObjObjectFaceIndex( state, i );
		trimesh->objects[i].face_count = tlObjObjectFaceCount( state, i );
	}	
	
	trimesh->face_count = tlObjFaceCount( state );
	trimesh->faces = malloc( sizeof(unsigned short) * trimesh->face_count * 3 );
	for( i = 0; i < trimesh->face_count; i++ )
	{
		unsigned int offset = i * 3;
		tlObjGetFace( state, i,
			&trimesh->faces[offset],
			&trimesh->faces[offset + 1],
			&trimesh->faces[offset + 2] );
	}

	trimesh->vertex_count = tlObjVertexCount( state );
	trimesh->vertex_format = vertex_format;
	trimesh->vertex_size = vertex_format & TL_FVF_XYZ ? 3 * sizeof(float) : 0;
	trimesh->vertex_size += vertex_format & TL_FVF_UV ? 2 * sizeof(float) : 0;
	trimesh->vertex_size += vertex_format & TL_FVF_NORMAL ? 3 * sizeof(float) : 0;
	trimesh->vertices = malloc( trimesh->vertex_count * trimesh->vertex_size );
	index = 0;
	for( i = 0; i < trimesh->vertex_count; i++ )
	{
		if( vertex_format & TL_FVF_XYZ )
		{
			x = &trimesh->vertices[index++];
			y = &trimesh->vertices[index++];
			z = &trimesh->vertices[index++];
		}
		
		if( vertex_format & TL_FVF_UV )
		{
			u = &trimesh->vertices[index++];
			v = &trimesh->vertices[index++];
		} 

		if( vertex_format & TL_FVF_NORMAL )
		{
			nx = &trimesh->vertices[index++];
			ny = &trimesh->vertices[index++];
			nz = &trimesh->vertices[index++];
		} 
			
		tlObjGetVertex( state, i, x, y, z, u, v, nx, ny, nz );
	}
	
	return trimesh;
}


/*----------------------------------------------------------------------------*/
tlTrimesh *tlLoadOBJ( const char *filename, unsigned int vertex_format )
{
	FILE *f = 0;
	tlTrimesh *trimesh = NULL;
	
	if( filename == NULL )
		return NULL;
	
	f = fopen( filename, "r" );
	if( f )
	{
		tlObjState *state = NULL;

		state = tlObjCreateState();
		if( state )
		{
			char buffer[1024];
			unsigned int size = 0;
			
			while( !feof( f ) )
			{
				size = (unsigned int) fread( buffer, 1, sizeof(buffer), f );
				tlObjParse( state, buffer, size, size < sizeof(buffer) ? 1 : 0 );
			}

			trimesh = tlCreateTrimeshFromObjState( state, vertex_format );
			
			tlObjDestroyState( state );
		}
		
		fclose( f );
	}
	
	return trimesh;
}


/*----------------------------------------------------------------------------*/
tlTrimesh *tlLoadTrimesh( const char* filename, unsigned int vertex_format )
{
	tlTrimesh *trimesh = NULL;
	
	if( tl3dsCheckFileExtension( filename ) == 0 )
		trimesh = tlLoad3DS( filename, vertex_format );
	else if( tlObjCheckFileExtension( filename ) == 0 )
		trimesh = tlLoadOBJ( filename, vertex_format );
	
	return trimesh;
}


/*----------------------------------------------------------------------------*/
void tlDeleteTrimesh( tlTrimesh *trimesh )
{
	unsigned int i = 0;
	
	if( trimesh == NULL )
		return;
		
	for( i = 0; i < trimesh->object_count; i++ )
		free( trimesh->objects[i].name );
	
	free( trimesh->objects );
	free( trimesh->faces );
	free( trimesh->vertices );
	free( trimesh );
}
