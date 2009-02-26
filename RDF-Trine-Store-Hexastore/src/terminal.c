#include "terminal.h"

int _hx_terminal_grow( hx_terminal* t );
int _hx_terminal_iter_prime_first_result( hx_terminal_iter* iter );
int _hx_terminal_binary_search ( const hx_terminal* t, const hx_node_id n, int* index );

hx_terminal* hx_new_terminal( hx_storage_manager* s ) {
	hx_terminal* terminal	= (hx_terminal*) calloc( 1, sizeof( hx_terminal ) );
	hx_node_id* p	= (hx_node_id*) calloc( TERMINAL_LIST_ALLOC_SIZE, sizeof( hx_node_id ) );
	terminal->ptr		= p;
	terminal->allocated	= TERMINAL_LIST_ALLOC_SIZE;
	terminal->used		= 0;
	terminal->refcount	= 0;
	terminal->storage	= s;
	return terminal;
}

int hx_free_terminal ( hx_terminal* list ) {
//	fprintf( stderr, "freeing terminal %p\n", list );
//	fprintf( stderr, "refcount is now %d\n", list->refcount );
	if (list->refcount <= 0) {
		if (list->ptr != NULL) {
//			fprintf( stderr, "free(list->ptr) called\n" );
			free( list->ptr );
		}
//		fprintf( stderr, "free(list) called\n" );
		free( list );
		return 0;
	} else {
		return 1;
	}
}

int hx_terminal_debug ( const char* header, hx_terminal* t, int newline ) {
	fprintf( stderr, "%s[", header );
	for(int i = 0; i < t->used; i++) {
		if (i > 0)
			fprintf( stderr, ", " );
		fprintf( stderr, "%d", (int) t->ptr[ i ] );
	}
	fprintf( stderr, "]" );
	if (newline > 0)
		fprintf( stderr, "\n" );
	return 0;
}

int hx_terminal_add_node ( hx_terminal* t, hx_node_id n ) {
	int i;
	
	if (n == (hx_node_id) 0) {
		fprintf( stderr, "*** hx_node_id cannot be zero in hx_terminal_add_node\n" );
		return 1;
	}
	
	int r	= _hx_terminal_binary_search( t, n, &i );
	if (r == 0) {
		// already in list. do nothing.
		return 1;
	} else {
		// not found. need to add at index i
//		fprintf( stderr, "list add [used: %d, allocated: %d]\n", (int) t->used, (int) t->allocated );
		if (t->used >= t->allocated) {
			_hx_terminal_grow( t );
		}
		
		for (int k = t->used - 1; k >= i; k--) {
			t->ptr[k + 1]	= t->ptr[k];
		}
		t->ptr[i]	= n;
		t->used++;
	}
	return 0;
}

int hx_terminal_contains_node ( hx_terminal* t, hx_node_id n ) {
	int i;
	int r	= _hx_terminal_binary_search( t, n, &i );
	if (r == 0) {
		return 1;
	} else {
		return 0;
	}
}

int hx_terminal_remove_node ( hx_terminal* t, hx_node_id n ) {
	int i;
	int r	= _hx_terminal_binary_search( t, n, &i );
	if (r == -1) {
		// not in list. do nothing.
		return 1;
	} else {
		// found. need to remove at index i
		for (int k = i; k < t->used; k++) {
			t->ptr[ k ]	= t->ptr[ k + 1 ];
		}
		t->used--;
	}
	return 0;
}

int _hx_terminal_grow( hx_terminal* t ) {
	size_t size		= t->allocated * 2;
//	fprintf( stderr, "growing terminal from %d to %d entries\n", (int) t->allocated, (int) size );
	hx_node_id* newp	= (hx_node_id*) calloc( size, sizeof( hx_node_id ) );
	for (int i = 0; i < t->used; i++) {
		newp[ i ]	= t->ptr[ i ];
	}
//	fprintf( stderr, "free(t->ptr) called\n" );
	free( t->ptr );
	t->ptr		= newp;
	t->allocated	= (list_size_t) size;
	return 0;
}

list_size_t hx_terminal_size ( hx_terminal* t ) {
	return t->used;
}

int _hx_terminal_binary_search ( const hx_terminal* t, const hx_node_id n, int* index ) {
	int low		= 0;
	int high	= t->used - 1;
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (t->ptr[mid] > n) {
			high	= mid - 1;
		} else if (t->ptr[mid] < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
}


hx_terminal_iter* hx_terminal_new_iter ( hx_terminal* terminal ) {
	hx_terminal_iter* iter	= (hx_terminal_iter*) calloc( 1, sizeof( hx_terminal_iter ) );
	iter->started		= 0;
	iter->finished		= 0;
	iter->terminal		= terminal;
	return iter;
}

int hx_free_terminal_iter ( hx_terminal_iter* iter ) {
	free( iter );
	return 0;
}

int hx_terminal_iter_finished ( hx_terminal_iter* iter ) {
	if (iter->started == 0) {
		_hx_terminal_iter_prime_first_result( iter );
	}
	return iter->finished;
}

int _hx_terminal_iter_prime_first_result( hx_terminal_iter* iter ) {
	iter->started	= 1;
	iter->index		= 0;
	if (iter->terminal->used == 0) {
		iter->finished	= 1;
		return 1;
	}
	return 0;
}

int hx_terminal_iter_current ( hx_terminal_iter* iter, hx_node_id* n ) {
	if (iter->started == 0) {
		_hx_terminal_iter_prime_first_result( iter );
	}
	if (iter->finished == 1) {
		return 1;
	} else {
		*n	= iter->terminal->ptr[ iter->index ];
		return 0;
	}
}

int hx_terminal_iter_next ( hx_terminal_iter* iter ) {
	if (iter->started == 0) {
//		fprintf( stderr, "terminal not started yet... priming first result...\n" );
		_hx_terminal_iter_prime_first_result( iter );
		if (iter->finished == 1) {
			return 1;
		}
	}
	
	if (iter->index >= (iter->terminal->used - 1)) {
//		fprintf( stderr, "terminal is exhausted...\n" );
		// terminal is exhausted
		iter->finished	= 1;
		iter->terminal	= NULL;
		return 1;
	} else {
		iter->index++;
//		fprintf( stderr, "terminal is now at [%d of %d]\n", iter->index + 1, iter->terminal->used );
		return 0;
	}
}

int hx_terminal_iter_seek( hx_terminal_iter* iter, hx_node_id n ) {
	int i;
	int r	= _hx_terminal_binary_search( iter->terminal, n, &i );
	if (r == 0) {
//		fprintf( stderr, "hx_terminal_iter_seek: found in list at index %d\n", i );
		iter->started	= 1;
		iter->index		= i;
		return 0;
	} else {
//		fprintf( stderr, "hx_terminal_iter_seek: didn't find in list\n" );
		return 1;
	}
}


int hx_terminal_write( hx_terminal* t, FILE* f ) {
	fputc( 'T', f );
	fwrite( &( t->used ), sizeof( list_size_t ), 1, f );
	fwrite( t->ptr, sizeof( hx_node_id ), t->used, f );
	return 0;
}

hx_terminal* hx_terminal_read( hx_storage_manager* s, FILE* f, int buffer ) {
	list_size_t used;
	int c	= fgetc( f );
	if (c != 'T') {
		fprintf( stderr, "*** Bad header cookie trying to read terminal from file.\n" );
		return NULL;
	}
	
	size_t read	= fread( &used, sizeof( list_size_t ), 1, f );
	if (read == 0) {
		return NULL;
	} else {
		list_size_t allocated;
		if (buffer == 0) {
			allocated	= used;
		} else {
			allocated	= used * 1.5;
		}
		
		hx_terminal* terminal	= (hx_terminal*) calloc( 1, sizeof( hx_terminal ) );
		hx_node_id* p	= (hx_node_id*) calloc( allocated, sizeof( hx_node_id ) );
		terminal->ptr		= p;
		terminal->allocated	= allocated;
		terminal->used		= used;
		terminal->refcount	= 0;
		size_t ptr_read	= fread( terminal->ptr, sizeof( hx_node_id ), used, f );
		if (ptr_read == 0) {
			hx_free_terminal( terminal );
			return NULL;
		} else {
			return terminal;
		}
	}
}

void hx_terminal_iter_debug ( char* header, hx_terminal_iter* iter, int newline ) {
	hx_terminal* t	= iter->terminal;
	fprintf( stderr, "%s[", header );
	for(int i = iter->index; i < t->used; i++) {
		if (i > 0)
			fprintf( stderr, ", " );
		fprintf( stderr, "%d", (int) t->ptr[ i ] );
	}
	fprintf( stderr, "]" );
	if (newline > 0)
		fprintf( stderr, "\n" );
}