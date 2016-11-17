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

#include "tlobj.h"
 
#include <string.h>
#include <stdlib.h>

/*----------------------------------------------------------------------------*/
typedef enum tlObjParsingState
{
	OBJ_STATE_SEARCH_COMMAND,
	OBJ_STATE_PARSE_COMMAND,
	OBJ_STATE_SEARCH_PARAMETER,
	OBJ_STATE_PARSE_PARAMETER,
	OBJ_STATE_SKIP_COMMENT,
	OBJ_STATE_DONE
} tlObjParsingState;


/*----------------------------------------------------------------------------*/
typedef struct tlObjObject
{
	char *name;
	unsigned int index, count;
} tlObjObject;

/*----------------------------------------------------------------------------*/
typedef struct vertex_map_item
{
	int v;
	unsigned int vt;
	unsigned int vn;
	unsigned int index;
} obj_vertex_map_item;

/*----------------------------------------------------------------------------*/
struct tlObjState
{
	tlObjObject **object_buffer;
	unsigned int object_buffer_size;
	unsigned int object_count;

	double *point_buffer;
	unsigned int point_buffer_size;
	unsigned int point_count;

	double *texcoord_buffer;
	unsigned int texcoord_buffer_size;
	unsigned int texcoord_count;

	double *normal_buffer;
	unsigned int normal_buffer_size;
	unsigned int normal_count;

	unsigned int *face_buffer;
	unsigned int face_buffer_size;
	unsigned int face_count;

	obj_vertex_map_item *vertex_map_buffer;
	unsigned int vertex_map_buffer_size;
	unsigned int vertex_map_count;

	tlObjParsingState parsing_state;
	tlObjParsingState previous_parsing_state;
	
	char *command_buffer;
	unsigned int command_buffer_size;
	unsigned int command_buffer_length;
	
	char *parameter_buffer;
	unsigned int parameter_buffer_size;
	unsigned int parameter_buffer_length;
	
};


/*----------------------------------------------------------------------------*/
static int obj_is_whitespace( char c )
{
	if( c == ' ' )
		return 1;

	if( c == '\n' )
		return 1;

	if( c == '\t' )
		return 1;
	
	if( c == '\r' )
		return 1;

	return 0;
}


/*----------------------------------------------------------------------------*/
static int obj_state_add_point(
	tlObjState *state,
	double x,
	double y,
	double z )
{
	unsigned int needed_size = (state->point_count + 1) * 3 * sizeof(double);
	
	if( needed_size > state->point_buffer_size )
	{
		unsigned int new_size = 128;
		double *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->point_buffer, new_size );
		if( new_buffer == 0 )
			return 1;
		
		state->point_buffer = new_buffer;	
		state->point_buffer_size = new_size;  
	}
	
	state->point_buffer[state->point_count*3] = x;
	state->point_buffer[state->point_count*3+1] = y;
	state->point_buffer[state->point_count*3+2] = z;
	state->point_count++;
	
	return 0;
}


/*----------------------------------------------------------------------------*/
static int obj_state_add_normal(
	tlObjState *state,
	double x,
	double y,
	double z )
{
	unsigned int needed_size = (state->normal_count + 1) * 3 * sizeof(double);
	
	if( needed_size > state->normal_buffer_size )
	{
		unsigned int new_size = 128;
		double *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->normal_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->normal_buffer = new_buffer;	
		state->normal_buffer_size = new_size;  
	}
	
	state->normal_buffer[state->normal_count*3] = x;
	state->normal_buffer[state->normal_count*3+1] = y;
	state->normal_buffer[state->normal_count*3+2] = z;
	state->normal_count++;
	
	return 0;
}

/*----------------------------------------------------------------------------*/
static int obj_state_add_texcoord( tlObjState *state, double u, double v )
{
	unsigned int needed_size = (state->texcoord_count + 1) * 3 * sizeof(double);
	
	if( needed_size > state->texcoord_buffer_size )
	{
		unsigned int new_size = 128;
		double *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->texcoord_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->texcoord_buffer = new_buffer;	
		state->texcoord_buffer_size = new_size;  
	}
	
	state->texcoord_buffer[state->texcoord_count*3] = u;
	state->texcoord_buffer[state->texcoord_count*3+1] = v;
	state->texcoord_count++;
	
	return 0;
}

/*----------------------------------------------------------------------------*/
static int obj_vertex_map_item_cmp( obj_vertex_map_item *a, obj_vertex_map_item *b )
{
	if( a->v > b->v )
		return 1;
	else if( a->v < b->v )
		return -1;

	if( a->vt > b->vt )
		return 1;
	else if( a->vt < b->vt )
		return -1;

	if( a->vn > b->vn )
		return 1;
	else if( a->vn < b->vn )
		return -1;
		
	return 0;
}

/*----------------------------------------------------------------------------*/
static int obj_state_map_vertex_find(
	tlObjState *state,
	unsigned int v,
	unsigned int vt,
	unsigned int vn,
	unsigned int *index )
{
	/* try to find an exiting one */	
	if( state->vertex_map_count > 0 )
	{
   		obj_vertex_map_item a = { v, vt, vn, 0 };
   	    int left = 0;
    	int center = 1;
    	int right = state->vertex_map_count - 1;
        
		while( left <= right )
		{
			int cmp;
			center = (left + right) / 2;

			cmp = obj_vertex_map_item_cmp( &state->vertex_map_buffer[center], &a );
			if( cmp == 0 )
			{
				*index = state->vertex_map_buffer[center].index;
				return 1;
			}
			else if( cmp > 0 )			
				right = center - 1;        
			else
				left = center + 1;
    	}
	}
	
	return 0;
}

/*----------------------------------------------------------------------------*/
static unsigned int obj_state_map_vertex_insert(
	tlObjState *state,
	unsigned int v,
	unsigned int vt,
	unsigned int vn )
{
	unsigned int i = 0;
   	unsigned int left = 0;
   	obj_vertex_map_item a = {v, vt, vn, 0 };
   	
	/* bring us close */
   	if( state->vertex_map_count > 8 )
   	{
	   	unsigned int right = state->vertex_map_count - 1;
	        
		while( (right - left) > 4 )
		{
			i = left + ((right - left) / 2);
	
			if( obj_vertex_map_item_cmp( &state->vertex_map_buffer[i], &a ) >= 0 )
				right = i - 1;        
			else
				left = i + 1;
		}
   	}
   	
	/* find first greater */
	for( i = left; i < state->vertex_map_count; i++ )
	{
		if( obj_vertex_map_item_cmp( &state->vertex_map_buffer[i], &a ) >= 0 )
			break;
	}
	
	/* move the rest */
	if( i < state->vertex_map_count )
	{
		memmove(
			&state->vertex_map_buffer[i+1],
			&state->vertex_map_buffer[i],
			sizeof(obj_vertex_map_item) * (state->vertex_map_count-i) );
	}
	
	/* insert new vertex */
	state->vertex_map_buffer[i].v = v;
	state->vertex_map_buffer[i].vt = vt;
	state->vertex_map_buffer[i].vn = vn;
	state->vertex_map_buffer[i].index = state->vertex_map_count;
	
	state->vertex_map_count++;
	
	return state->vertex_map_count - 1;
}

/*----------------------------------------------------------------------------*/
static void obj_state_map_vertex_increase( tlObjState *state )
{
	/* check if there is enough room for another element */
	unsigned int needed_size = (state->vertex_map_count + 1) * sizeof(obj_vertex_map_item);
	
	if( needed_size > state->vertex_map_buffer_size )
	{
		unsigned int new_size = 128;
		obj_vertex_map_item *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->vertex_map_buffer, new_size );
		
		state->vertex_map_buffer = new_buffer;	
		state->vertex_map_buffer_size = new_size;  
	}
}

/*----------------------------------------------------------------------------*/
static unsigned int obj_state_map_vertex(
	tlObjState *state,
	unsigned int v,
	unsigned int vt,
	unsigned int vn )
{
	unsigned int index;

	if( obj_state_map_vertex_find( state, v, vt, vn, &index ) )
		return index;
	
	obj_state_map_vertex_increase( state );

	return obj_state_map_vertex_insert( state, v, vt, vn );
}

/*----------------------------------------------------------------------------*/
void obj_quicksort_vertex_map( obj_vertex_map_item *map, int left, int right )
{
	if( right > left )
	{
		int i = left;
		int j = right;
		int pivot = (right+left)/2;
		obj_vertex_map_item tmp;

		while( i <= j)
        {    
            while( map[i].index < pivot ) i++; 
            while( map[j].index > pivot ) j--; 
            if( i <= j )
            {
            	tmp = map[i];
				map[i] = map[j];
				map[j] = tmp;
                i++; j--;
            }
        }

        if( left < j )
        	obj_quicksort_vertex_map( map, left, j );
        	
        if( i < right )
        	obj_quicksort_vertex_map( map, i, right );
	}
}
        
/*----------------------------------------------------------------------------*/
static int obj_state_add_face(
	tlObjState *state,
	unsigned int a,
	unsigned int b,
	unsigned int c )
{
	unsigned int needed_size
		= (state->face_count + 1) * 3 * sizeof(unsigned int);
	
	if( needed_size > state->face_buffer_size )
	{
		unsigned int new_size = 128;
		unsigned int *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->face_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->face_buffer = new_buffer;	
		state->face_buffer_size = new_size;  
	}

	state->face_buffer[state->face_count*3] = a;
	state->face_buffer[state->face_count*3+1] = b;
	state->face_buffer[state->face_count*3+2] = c;

	state->face_count++;
	
	return 0;
}


/*----------------------------------------------------------------------------*/
static int obj_state_add_object(
	tlObjState *state,
	const char *name,
	unsigned int name_size )
{
	unsigned int needed_size
		= (state->object_count + 1) * sizeof(tlObjObject *); 
	tlObjObject *obj = 0;

	if( state == NULL )
		return 1;
		
	if( needed_size > state->object_buffer_size )
	{
		unsigned int new_size = 128;
		tlObjObject **new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->object_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->object_buffer = new_buffer;	
		state->object_buffer_size = new_size;  
	}

	obj = malloc( sizeof(tlObjObject) );
	obj->index = state->face_count;
	obj->name = malloc( name_size );
	memcpy( obj->name, name, name_size );
	state->object_buffer[ state->object_count ] = obj;
	state->object_count++;

	return 0;
}


/*----------------------------------------------------------------------------*/
static void obj_process_command( tlObjState *state )
{
	if( state == NULL )
		return;

	if( strcmp( state->command_buffer, "o" ) == 0 )
	{
		/* safe face count */
		if( state->object_count > 0 )
		{
			tlObjObject *obj = state->object_buffer[ state->object_count - 1 ];
			obj->count = state->face_count - obj->index;
		}

		obj_state_add_object(
			state,
			state->parameter_buffer,
			state->parameter_buffer_length );
	}
	else if( strcmp( state->command_buffer, "v" ) == 0 )
	{
		double x, y, z;
		char *ptr = state->parameter_buffer;
		x = strtod( ptr, &ptr );
		y = strtod( ptr, &ptr );
		z = strtod( ptr, &ptr );
		
		obj_state_add_point( state, x, y, z );
	}
	else if( strcmp( state->command_buffer, "vn" ) == 0 )
	{
		double x, y, z;
		char *ptr = state->parameter_buffer;
		x = strtod( ptr, &ptr );
		y = strtod( ptr, &ptr );
		z = strtod( ptr, &ptr );
		
		obj_state_add_normal( state, x, y, z );
	}
	else if( strcmp( state->command_buffer, "vt" ) == 0 )
	{
		double u, v;
		char *ptr = state->parameter_buffer;
		u = strtod( ptr, &ptr );
		v = strtod( ptr, &ptr );

		obj_state_add_texcoord( state, u, v );
	}
	else if( strcmp( state->command_buffer, "f" ) == 0 )
	{ 
		unsigned int count = 0;
		int buffer[3];
		char *ptr = state->parameter_buffer;
		
		while( *ptr != 0 )
		{
			int v = 0, vn = 0, vt = 0;

			/* parse vertex index */
			v = strtol( ptr, &ptr, 10 );

			/* parse texcoord index */
			if( *ptr == '/' )
			{
				ptr++;
				vt = strtol( ptr, &ptr, 10 );
			}

			/* parse normal index */
			if( *ptr == '/' )
			{
				ptr++;
				vn = strtol( ptr, &ptr, 10 );
			}

			/* skip spaces */
			while( *ptr == ' ' )
				ptr++;

			count++;
			
			if( v < 0 )
				v += state->point_count + 1;

			if( vt < 0 )
				vt += state->texcoord_count + 1;

			if( vn < 0 )
				vn += state->normal_count + 1;
				
			/* make tris from fan */
			if( count < 4 )
			{
				buffer[count-1] = obj_state_map_vertex( state, v, vt, vn );
			}				
			else
			{
				buffer[1] = buffer[2];
				buffer[2] = obj_state_map_vertex( state, v, vt, vn );
			}

			if( count > 2 )
			{
				obj_state_add_face( state, buffer[0], buffer[1], buffer[2] );
			}	

		}
	}
}


/*----------------------------------------------------------------------------*/
static int obj_command_buffer_add( tlObjState *state, char c )
{
	unsigned int needed_size = state->command_buffer_length + 1;

	if( needed_size > state->command_buffer_size )
	{
		unsigned int new_size = 128;
		char *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->command_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->command_buffer = new_buffer;	
		state->command_buffer_size = new_size;  
	}
		
	state->command_buffer[ state->command_buffer_length ] = c;
	state->command_buffer_length++;

	return 0;
}


/*----------------------------------------------------------------------------*/
static int obj_parameter_buffer_add( tlObjState *state, char c )
{
	unsigned int needed_size = state->parameter_buffer_length + 1;

	if( needed_size > state->parameter_buffer_size )
	{
		unsigned int new_size = 128;
		char *new_buffer;
		
		while( new_size < needed_size )
			new_size = new_size * 2;
		
		new_buffer = realloc( state->parameter_buffer, new_size );
		if( new_buffer == NULL )
			return 1;
		
		state->parameter_buffer = new_buffer;	
		state->parameter_buffer_size = new_size;  
	}
		
	state->parameter_buffer[ state->parameter_buffer_length ] = c;
	state->parameter_buffer_length++;

	return 0;
}


/*----------------------------------------------------------------------------*/
tlObjState *tlObjCreateState()
{
	tlObjState *state = malloc( sizeof(tlObjState) );

	if( state )
	{
		memset( state, 0, sizeof(tlObjState) );
		state->parsing_state = OBJ_STATE_SEARCH_COMMAND;
		state->previous_parsing_state = OBJ_STATE_SEARCH_COMMAND;
	}
		
	return state;	
}


/*----------------------------------------------------------------------------*/
int tlObjResetState( tlObjState *state )
{
	unsigned int i = 0;
	
	for( i = 0; i<state->object_count; i++ )
	{
		tlObjObject *obj = state->object_buffer[i];
		if( obj == NULL )
			continue;
		
		if( obj->name )
			free( obj->name );
		obj->name = NULL;
		
		free( obj );
	}
	
	if( state->object_buffer )
		free( state->object_buffer );
			
	if( state->point_buffer )
		free( state->point_buffer );

	if( state->face_buffer )
		free( state->face_buffer );

	if( state->vertex_map_buffer )
		free( state->vertex_map_buffer );

	if( state->normal_buffer )
		free( state->normal_buffer );

	if( state->texcoord_buffer )
		free( state->texcoord_buffer );

	if( state->command_buffer )
		free( state->command_buffer );

	if( state->parameter_buffer )
		free( state->parameter_buffer );

	memset( state, 0, sizeof(tlObjState) );

	state->parsing_state = OBJ_STATE_SEARCH_COMMAND;
	state->previous_parsing_state = OBJ_STATE_SEARCH_COMMAND;

	return 0;
}


/*----------------------------------------------------------------------------*/
void tlObjDestroyState( tlObjState *state )
{
	if( state )
	{
		tlObjResetState( state );
		free( state );
	}
}


/*----------------------------------------------------------------------------*/
int tlObjParse(
	tlObjState *state,
	const char *bytes,
	unsigned int size,
	int last )
{
	unsigned int i = 0;

	if( state == NULL )
		return 1;

	while( i < size )
	{
		char c = bytes[i];
		
		if( c == '#' )
		{
			state->previous_parsing_state = state->parsing_state;
			state->parsing_state = OBJ_STATE_SKIP_COMMENT;
			i++;
			continue;
		}
				
		if( state->parsing_state == OBJ_STATE_SKIP_COMMENT )
		{
			if( c == '\n' )
				state->parsing_state = state->previous_parsing_state;
			i++;
			continue;
		}
		
		switch( state->parsing_state )
		{
		case OBJ_STATE_SEARCH_COMMAND:
			if( obj_is_whitespace( c ) )
				i++;
			else
				state->parsing_state = OBJ_STATE_PARSE_COMMAND;
				
			break;
				
		case OBJ_STATE_PARSE_COMMAND:
			if( obj_is_whitespace( c ) )
			{
				state->parsing_state = OBJ_STATE_SEARCH_PARAMETER;
				obj_command_buffer_add( state, 0 );
				continue;
			}
			
			obj_command_buffer_add( state, c );

			i++;

			break;

		case OBJ_STATE_SEARCH_PARAMETER:
			/* handle missing paramter */
			if( c == '\n' )
			{
				state->parsing_state = OBJ_STATE_PARSE_PARAMETER;
				continue;
			}
				
			if( obj_is_whitespace( c ) )
				i++;
			else
				state->parsing_state = OBJ_STATE_PARSE_PARAMETER;
				
			break;
					
		case OBJ_STATE_PARSE_PARAMETER:
			if( c == '\n' )
			{
				/* trim */
				while( obj_is_whitespace( state->parameter_buffer[ state->parameter_buffer_length-1 ] ) )
					state->parameter_buffer_length--;
				obj_parameter_buffer_add( state, 0 );
				
				obj_process_command( state );
				
				state->parameter_buffer_length = 0;
				state->command_buffer_length = 0;
				state->parsing_state = OBJ_STATE_SEARCH_COMMAND;
			}
			else
			{
				obj_parameter_buffer_add( state, c );
				i++;
			}

			break;
			
		default:
			i++;
			break;
		}
	}
	
	if( last != 0 )
	{
		tlObjObject *object = NULL;

		/* make sure we have at least one object */
		if( state->object_count == 0 )
		{
			obj_state_add_object( state, "n/a", 4 );
			state->object_buffer[ state->object_count - 1 ]->index = 0;
		}
		
		object = state->object_buffer[ state->object_count - 1 ];
		object->count = state->face_count - object->index;
	}

	if( last )
	{
		/* sort map, so face access is correct */
		obj_quicksort_vertex_map( state->vertex_map_buffer, 0, state->vertex_map_count - 1 );
		state->parsing_state = OBJ_STATE_DONE;
	}
	
	return 0;
}

/*----------------------------------------------------------------------------*/
unsigned int tlObjObjectCount( tlObjState *state )
{
	if( state == NULL )
		return 0;
	
	if( state->parsing_state != OBJ_STATE_DONE )
		return 0;

	return state->object_count;
}


/*----------------------------------------------------------------------------*/
const char *tlObjObjectName( tlObjState *state, unsigned int object )
{
	if( state == NULL )
		return NULL;

	if( state->parsing_state != OBJ_STATE_DONE )
		return NULL;

	if( object >= state->object_count )
		return NULL;
		
	return state->object_buffer[object]->name;
}


/*----------------------------------------------------------------------------*/
unsigned int tlObjObjectFaceCount( tlObjState *state, unsigned int object )
{
	if( state == NULL )
		return 0;

	if( state->parsing_state != OBJ_STATE_DONE )
		return 0;

	if( object >= state->object_count )
		return 0;
		
	return state->object_buffer[object]->count;
}


/*----------------------------------------------------------------------------*/
unsigned int tlObjObjectFaceIndex( tlObjState *state, unsigned int object )
{
	
	if( state == NULL )
		return 0;

	if( state->parsing_state != OBJ_STATE_DONE )
		return 0;

	if( object >= state->object_count )
		return 0;
		
	return state->object_buffer[object]->index;
}


/*----------------------------------------------------------------------------*/
unsigned int tlObjVertexCount( tlObjState *state )
{
	if( state == NULL )
		return 0;

	if( state->parsing_state != OBJ_STATE_DONE )
		return 0;

	return state->vertex_map_count;
}


/*----------------------------------------------------------------------------*/
int tlObjGetVertexDouble(
	tlObjState *state,
	unsigned int index,
	double *x, double *y, double *z,
	double *tu, double *tv,
	double *nx, double *ny, double *nz )
{
	unsigned int v = 0, vt = 0, vn = 0;
	
	if( state == NULL )
		return 1;

	if( index >= state->vertex_map_count )
		return 1;
		
	v = state->vertex_map_buffer[index].v - 1;
	vt = state->vertex_map_buffer[index].vt - 1;
	vn = state->vertex_map_buffer[index].vn - 1;

	if( state->point_buffer && v < state->point_count )
	{
		if( x )
			*x = state->point_buffer[ v * 3 ];
	
		if( y )
			*y = state->point_buffer[ v * 3 + 1];
	
		if( z )
			*z = state->point_buffer[ v * 3 + 2];
	}

	if( state->texcoord_buffer && vt < state->texcoord_count )
	{
		if( tu )
			*tu = state->texcoord_buffer[ vt * 3 ];
	
		if( tv )
			*tv = state->texcoord_buffer[ vt * 3 + 1];
	}

	if( state->normal_buffer && vn < state->normal_count )
	{
		if( nx )
			*nx = state->normal_buffer[ vn * 3 ];
	
		if( ny )
			*ny = state->normal_buffer[ vn * 3 + 1];
	
		if( nz )
			*nz = state->normal_buffer[ vn * 3 + 2];
	}

	
	return 0;
}


/*----------------------------------------------------------------------------*/
int tlObjGetVertex(
	tlObjState *state,
	unsigned int index,
	float *x, float *y, float *z,
	float *tu, float *tv,
	float *nx, float *ny, float *nz )
{
	unsigned int v = 0, vt = 0, vn = 0;
	
	if( state == NULL )
		return 1;

	if( index >= state->vertex_map_count )
		return 1;
		
	v = state->vertex_map_buffer[index].v - 1;
	vt = state->vertex_map_buffer[index].vt - 1;
	vn = state->vertex_map_buffer[index].vn - 1;

	if( state->point_buffer && v < state->point_count )
	{
		if( x )
			*x = (float)state->point_buffer[ v * 3 ];
	
		if( y )
			*y = (float)state->point_buffer[ v * 3 + 1];
	
		if( z )
			*z = (float)state->point_buffer[ v * 3 + 2];
	}

	if( state->texcoord_buffer && vt < state->texcoord_count )
	{
		if( tu )
			*tu = (float)state->texcoord_buffer[ vt * 3 ];
	
		if( tv )
			*tv = (float)state->texcoord_buffer[ vt * 3 + 1];
	}

	if( state->normal_buffer && vn < state->normal_count )
	{
		if( nx )
			*nx = (float)state->normal_buffer[ vn * 3 ];
	
		if( ny )
			*ny = (float)state->normal_buffer[ vn * 3 + 1];
	
		if( nz )
			*nz = (float)state->normal_buffer[ vn * 3 + 2];
	}

	
	return 0;
}


/*----------------------------------------------------------------------------*/
unsigned int tlObjFaceCount( tlObjState *state )
{
	if( state == NULL )
		return 0;
	
	return state->face_count;
}


/*----------------------------------------------------------------------------*/
int tlObjGetFaceInt(
	tlObjState *state,
	unsigned int index,
	unsigned int *a,
	unsigned int *b,
	unsigned int *c )
{
	unsigned int face = 0;

	if( state == NULL )
		return 1;

	if( state->face_buffer && face <= state->face_count )
	{
		if( a )
			*a = state->face_buffer[ index * 3 ];
	
		if( b )
			*b = state->face_buffer[ index * 3 + 1 ];
	
		if( c )
			*c = state->face_buffer[ index * 3 + 2 ];
	}

	return 0;
}


/*----------------------------------------------------------------------------*/
int tlObjGetFace(
	tlObjState *state,
	unsigned int index,
	unsigned short *a,
	unsigned short *b,
	unsigned short *c )
{
	unsigned int face = 0;

	if( state == NULL )
		return 1;

	if( state->face_buffer && face <= state->face_count )
	{
		if( a )
			*a = state->face_buffer[ index * 3 ];
	
		if( b )
			*b = state->face_buffer[ index * 3 + 1 ];
	
		if( c )
			*c = state->face_buffer[ index * 3 + 2 ];
	}

	return 0;
}


/*----------------------------------------------------------------------------*/
int tlObjCheckFileExtension( const char *filename )
{
	const char *ext = 0, *tmp = filename;
	
	if( filename == NULL )
		return 1;
			
	while( *tmp != 0 )
	{
		if( *tmp == '.' )
			ext = tmp + 1;
		
		tmp++;
	} 
	
	/* no extension found */
	if( ext == 0 )
		return 1;

	if( (ext[0] == 'o' || ext[0] == 'O')
		&& (ext[1] == 'b' || ext[1] == 'B')
		&& (ext[2] == 'j' || ext[2] == 'J')
		&& (ext[3] == 0) )
		return 0;
		
	return 1;
}
