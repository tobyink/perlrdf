#ifndef _HEXASTORE_H
#define _HEXASTORE_H

#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>

#include "hexastore_types.h"
#include "index.h"
#include "terminal.h"
#include "vector.h"
#include "head.h"

enum {
	RDF_ITER_FLAGS_BOUND_A	= 1,
	RDF_ITER_FLAGS_BOUND_B	= 2,
	RDF_ITER_FLAGS_BOUND_C	= 4,
};

static const int RDF_ITER_TYPE_MASK	= 0x07;
static const int RDF_ITER_TYPE_FFF	= 0;
static const int RDF_ITER_TYPE_BFF	= RDF_ITER_FLAGS_BOUND_A;
static const int RDF_ITER_TYPE_BBF	= RDF_ITER_FLAGS_BOUND_A | RDF_ITER_FLAGS_BOUND_B;

typedef struct {
	hx_index* index;
	int flags;
	size_t a_index;
	size_t b_index;
	size_t c_index;
	hx_head* head;
	hx_vector* vector;
	hx_terminal* terminal;
	int started;
	int finished;
} hx_iter;

hx_iter* hx_new_iter ( hx_index* index );
hx_iter* hx_new_iter1 ( hx_index* index, rdf_node a );
hx_iter* hx_new_iter2 ( hx_index* index, rdf_node a, rdf_node b );
int hx_free_iter ( hx_iter* iter );

int hx_iter_finished ( hx_iter* iter );
int hx_iter_current ( hx_iter* iter, rdf_node* s, rdf_node* p, rdf_node* o );
int hx_iter_next ( hx_iter* iter );

#endif
