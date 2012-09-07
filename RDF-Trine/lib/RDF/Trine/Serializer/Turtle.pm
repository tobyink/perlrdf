package RDF::Trine::Serializer::Turtle;

use URI;
use Carp;
use Encode;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr reftype);

use RDF::Trine qw(variable iri);
use RDF::Trine::Statement::Triple;
use RDF::Trine::Namespace qw(rdf);

use constant DEBUG => 0;

use constant media_types => qw( text/turtle application/turtle );
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
use MooseX::Types::Moose qw(Any HashRef Object Str Undef);

with qw(
	RDF::Trine::Serializer::API::Graph
);

has used_ns => (
	is       => 'rw',
	isa      => HashRef,
	default  => sub { +{} },
);

has ns => (
	is       => 'rw',
	isa      => HashRef|Object,
	default  => sub { +{} },
);

has base_uri => (
	is       => 'rw',
	isa      => Str|Undef,
);

sub BUILDARGS {
	my $class = shift;
	my $ns    = +{};
	my $base_uri;

	if (@_) {
		if (scalar(@_) == 1 and reftype($_[0]) eq 'HASH') {
			$ns = shift;
		} else {
			my %args = @_;
			if (exists $args{ base }) {
				$base_uri = $args{ base };
			}
			if (exists $args{ base_uri }) {
				$base_uri = $args{ base_uri };
			}
			if (exists $args{ namespaces }) {
				$ns = $args{ namespaces };
			}
		}
	}
	
	my %rev;
	while (my ($ns, $uri) = each(%{ $ns })) {
		if (blessed($uri)) {
			$uri = $uri->uri_value;
			if (blessed($uri)) {
				$uri = $uri->uri_value;
			}
		}
		$rev{ $uri } = $ns;
	}
	
	+{
		ns       => \%rev,
		base_uri => $base_uri,
	};
}

sub model_to_file {
	my ($self, $model, $fh) = @_;
	my $sink = RDF::Trine::Serializer::FileSink->new($fh);
	
	my $st     = RDF::Trine::Statement::Triple->new( map { variable($_) } qw(s p o) );
	my $pat    = RDF::Trine::Pattern->new( $st );
	my $stream = $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter   = $stream->as_statements( qw(s p o) );
	
	$self->__serialize_iterator(
		$sink,
		$iter,
		seen  => {},
		level => 0,
		tab   => "\t",
		@_,
		model => $model,
	);
	return 1;
}

sub model_to_string {
	my $self   = shift;
	my $model  = shift;
	my $sink   = RDF::Trine::Serializer::StringSink->new();
	
	my $st     = RDF::Trine::Statement::Triple->new( map { variable($_) } qw(s p o) );
	my $pat    = RDF::Trine::Pattern->new( $st );
	my $stream = $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter   = $stream->as_statements( qw(s p o) );
	
	$self->__serialize_iterator(
		$sink,
		$iter,
		seen   => {},
		level  => 0,
		tab    => "\t",
		@_,
		model  => $model,
		string => 1,
	);
	return $sink->string;
}

sub _serialize_graph {
	my ($self, $iter, $fh) = (shift, shift, shift);
	my %args = @_;
	my $sink = RDF::Trine::Serializer::FileSink->new($fh);
	$self->__serialize_iterator($sink, $iter, %args);
	return 1;
}

sub __serialize_iterator {
	my $self    = shift;
	my $sink    = shift;
	my $iter    = shift;
	my %args    = @_;
	my $seen    = $args{ seen }  || {};
	my $level   = $args{ level } || 0;
	my $tab     = $args{ tab }   || "\t";
	my $indent  = $tab x $level;
	my %ns      = reverse(%{ $self->ns });
	my @nskeys  = sort keys %ns;
	
	unless ($sink->can('prepend')) {
		if (@nskeys) {
			foreach my $ns (@nskeys) {
				my $uri = $ns{ $ns };
				$sink->emit("\@prefix $ns: <$uri> .\n");
			}
			$sink->emit("\n");
		}
	}
	if ($self->base_uri) {
		$sink->emit("\@base <".$self->base_uri."> .\n\n");
	}
	
	my $last_subj;
	my $last_pred;
	
	my $open_triple = 0;
	while (my $st = $iter->next) {
		my $subj = $st->subject;
		my $pred = $st->predicate;
		my $obj  = $st->object;
		
		# we're abusing the seen hash here as the key isn't really a node value,
		# but since it isn't a valid node string being used it shouldn't collide
		# with real data. we set this here so that later on when we check for
		# single-owner bnodes (when attempting to use the [...] concise syntax),
		# bnodes that have already been serialized as the 'head' of a statement
		# aren't considered as single-owner. This is because the output string
		# is acting as a second ownder of the node -- it's already been emitted
		# as something like '_:foobar', so it can't also be output as '[...]'.
		$seen->{ '  heads' }{ $subj->as_string }++;
		
		if (my $model = $args{model}) {
			if (my $head = $self->__statement_describes_list($model, $st)) {
				warn "found a rdf:List head " . $head->as_string . " for the subject in statement " . $st->as_string if DEBUG;
				if ($model->count_statements(undef, undef, $head)) {
					# the rdf:List appears as the object of a statement, and so
					# will be serialized whenever we get to serializing that
					# statement
					warn "next" if DEBUG;
					next;
				}
			}
		}
		
		if ($seen->{ $subj->as_string }) {
			warn "next on seen subject " . $st->as_string if DEBUG;
			next;
		}
		
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				$sink->emit(qq[, ]);
				$self->__serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
			} else {
				# start a new predicate
				$sink->emit(qq[ ;\n${indent}$tab]);
				$self->__turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
				$sink->emit(' ');
				$self->__serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				$sink->emit(qq[ .\n${indent}]);
			}
			$open_triple = 1;
			$self->__turtle( $sink, $subj, 0, $seen, $level, $tab, %args );
			
			warn '-> ' . $pred->as_string if DEBUG;
			$sink->emit(' ');
			$self->__turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
			$sink->emit(' ');
			$self->__serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
		}
	} continue {
		if (blessed($last_subj) and not($last_subj->equal($st->subject))) {
# 			warn "marking " . $st->subject->as_string . " as seen";
			$seen->{ $last_subj->as_string }++;
		}
# 		warn "setting last subject to " . $st->subject->as_string;
		$last_subj	= $st->subject;
		$last_pred	= $st->predicate;
	}
	
	if ($open_triple) {
		$sink->emit(qq[ .\n]);
	}
	
	if ($sink->can('prepend')) {
		my @used_nskeys = keys %{ $self->used_ns };
		if (@used_nskeys) {
			my $string	= '';
			foreach my $ns (@used_nskeys) {
				my $uri	= $ns{ $ns };
				$string	.= "\@prefix $ns: <$uri> .\n";
			}
			$string	.= "\n";
			$sink->prepend($string);
		}
	}
}


sub serialize_node {
	return $_[0]->node_as_concise_string( $_[1] );
}

sub __serialize_object_to_file {
	my $self	= shift;
	my $sink	= shift;
	my $subj	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $indent	= $tab x $level;
	
	if (my $model = $args{model}) {
		if ($subj->isa('RDF::Trine::Node::Blank')) {
			if ($self->__check_valid_rdf_list( $subj, $model )) {
# 				warn "node is a valid rdf:List: " . $subj->as_string . "\n";
				return $self->__turtle_rdf_list( $sink, $subj, $model, $seen, $level, $tab, %args );
			} else {
				my $count	= $model->count_statements( undef, undef, $subj );
				my $rec		= $model->count_statements( $subj, undef, $subj );
				warn "count=$count, rec=$rec for node " . $subj->as_string if DEBUG;
				if ($count == 1 and $rec == 0) {
					unless ($seen->{ $subj->as_string }++ or $seen->{ '  heads' }{ $subj->as_string }) {
						my $iter	= $model->get_statements( $subj, undef, undef );
						my $last_pred;
						my $triple_count	= 0;
						$sink->emit("[");
						while (my $st = $iter->next) {
							my $pred	= $st->predicate;
							my $obj		= $st->object;
							
							# continue an existing subject
							if ($pred->equal( $last_pred )) {
								# continue an existing predicate
								$sink->emit(qq[, ]);
								$self->__serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
#								$self->__turtle( $fh, $obj, 2, $seen, $level, $tab, %args );
							} else {
								# start a new predicate
								if ($triple_count == 0) {
									$sink->emit(qq[\n${indent}${tab}${tab}]);
								} else {
									$sink->emit(qq[ ;\n${indent}$tab${tab}]);
								}
								$self->__turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
								$sink->emit(' ');
								$self->__serialize_object_to_file( $sink, $obj, $seen, $level+1, $tab, %args );
							}
							
							$last_pred	= $pred;
							$triple_count++;
						}
						if ($triple_count) {
							$sink->emit("\n${indent}${tab}");
						}
						$sink->emit("]");
						return;
					}
				}
			}
		}
	}
	
	$self->__turtle( $sink, $subj, 2, $seen, $level, $tab, %args );
}

sub __statement_describes_list {
	my $self	= shift;
	my $model	= shift;
	my $st		= shift;
	my $subj	= $st->subject;
	my $pred	= $st->predicate;
	my $obj		= $st->object;
	if ($model->count_statements($subj, $rdf->first) and $model->count_statements($subj, $rdf->rest)) {
# 		warn $subj->as_string . " looks like a rdf:List element";
		if (my $head = $self->__node_belongs_to_valid_list( $model, $subj )) {
			return $head;
		}
	}
	
	return;
}

sub __node_belongs_to_valid_list {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	while ($model->count_statements( undef, $rdf->rest, $node )) {
		my $iter		= $model->get_statements( undef, $rdf->rest, $node );
		my $s			= $iter->next;
		my $ancestor	= $s->subject;
		unless (blessed($ancestor)) {
# 			warn "failed to get an expected rdf:List element ancestor";
			return 0;
		}
		($node)	= $ancestor;
# 		warn "stepping back to rdf:List element ancestor " . $node->as_string;
	}
	if ($self->__check_valid_rdf_list( $node, $model )) {
		return $node;
	} else {
		return;
	}
}

sub __check_valid_rdf_list {
	my $self	= shift;
	my $head	= shift;
	my $model	= shift;
# 	warn '--------------------------';
# 	warn "checking if node " . $head->as_string . " is a valid rdf:List\n";
	
	my $headrest	= $model->count_statements( undef, $rdf->rest, $head );
	if ($headrest) {
# 		warn "\tnode " . $head->as_string . " seems to be the middle of an rdf:List\n";
		return 0;
	}
	
	my %list_elements;
	my $node	= $head;
	until ($node->equal( $rdf->nil )) {
		$list_elements{ $node->as_string }++;
		
		unless ($node->isa('RDF::Trine::Node::Blank')) {
# 			warn "\tnode " . $node->as_string . " isn't a blank node\n";
			return 0;
		}
		
		my $first	= $model->count_statements( $node, $rdf->first );
		unless ($first == 1) {
# 			warn "\tnode " . $node->as_string . " has $first rdf:first links when 1 was expected\n";
			return 0;
		}
		
		my $rest	= $model->count_statements( $node, $rdf->rest );
		unless ($rest == 1) {
# 			warn "\tnode " . $node->as_string . " has $rest rdf:rest links when 1 was expected\n";
			return 0;
		}
		
		my $in		= $model->count_statements( undef, undef, $node );
		unless ($in < 2) {
# 			warn "\tnode " . $node->as_string . " has $in incoming links when 2 were expected\n";
			return 0;
		}
		
		if (not($head->equal( $node ))) {
			# It's OK for the head of a list to have any outgoing links (e.g. (1 2) ex:p "o"
			# but internal list elements should have only the expected links of rdf:first,
			# rdf:rest, and optionally an rdf:type rdf:List
			my $out		= $model->count_statements( $node );
			unless ($out == 2 or $out == 3) {
# 				warn "\tnode " . $node->as_string . " has $out outgoing links when 2 or 3 were expected\n";
				return 0;
			}
			
			if ($out == 3) {
				my $type	= $model->count_statements( $node, $rdf->type, $rdf->List );
				unless ($type == 1) {
# 					warn "\tnode " . $node->as_string . " has more outgoing links than expected\n";
					return 0;
				}
			}
		}
		
		
		
		my @links	= $model->objects_for_predicate_list( $node, $rdf->first, $rdf->rest );
		foreach my $l (@links) {
			if ($list_elements{ $l->as_string }) {
				warn $node->as_string . " is repeated in the list" if DEBUG;
				return 0;
			}
		}
		
		($node)	= $model->objects_for_predicate_list( $node, $rdf->rest );
		unless (blessed($node)) {
# 			warn "\tno valid rdf:rest object found";
			return 0;
		}
# 		warn "\tmoving on to rdf:rest object " . $node->as_string . "\n";
	}
	
# 	warn "\tlooks like a valid rdf:List\n";
	return 1;
}

sub __turtle_rdf_list {
	my $self	= shift;
	my $sink	= shift;
	my $head	= shift;
	my $model	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $node	= $head;
	my $count	= 0;
	$sink->emit('(');
	until ($node->equal( $rdf->nil )) {
		if ($count) {
			$sink->emit(' ');
		}
		my ($value)	= $model->objects_for_predicate_list( $node, $rdf->first );
		$self->__serialize_object_to_file( $sink, $value, $seen, $level, $tab, %args );
		$seen->{ $node->as_string }++;
		($node)		= $model->objects_for_predicate_list( $node, $rdf->rest );
		$count++;
	}
	$sink->emit(')');
}

sub __node_concise_string {
	my $self	= shift;
	my $obj		= shift;
	if ($obj->is_literal and $obj->has_datatype) {
		my $dt	= $obj->literal_datatype;
		if ($dt =~ m<^http://www.w3.org/2001/XMLSchema#(integer|double|decimal)$> and $obj->is_canonical_lexical_form) {
			my $value	= $obj->literal_value;
			return $value;
		} else {
			my $dtr	= iri($dt);
			my $literal	= $obj->literal_value;
			my $qname;
			eval {
				my ($ns,$local)	= $dtr->qname;
				if (blessed($self) and exists $self->ns->{$ns}) {
					$qname	= join(':', $self->ns->{$ns}, $local);
					$self->used_ns->{ $self->ns->{$ns} }++;
				}
			};
			if ($qname) {
				my $escaped	= $obj->_escaped_value;
				return qq["$escaped"^^$qname];
			}
		}
	} elsif ($obj->isa('RDF::Trine::Node::Resource')) {
		my $value;
		eval {
			my ($ns,$local)	= $obj->qname;
			if (blessed($self) and exists $self->ns->{$ns}) {
				$value	= join(':', $self->ns->{$ns}, $local);
				$self->used_ns->{ $self->ns->{$ns} }++;
			}
		};
		if ($value) {
			return $value;
		}
	}
	return;
}

=item C<< node_as_concise_string >>

Returns a string representation using common Turtle syntax shortcuts (e.g. for numeric literals).

=cut

sub node_as_concise_string {
	my $self	= shift;
	my $obj		= shift;
	my $str		= $self->__node_concise_string( $obj );
	if (defined($str)) {
		return $str;
	} else {
		return $obj->as_ntriples;
	}
}

sub __turtle {
	my $self	= shift;
	my $sink	= shift;
	my $obj		= shift;
	my $pos		= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	
	if ($obj->isa('RDF::Trine::Node::Resource') and $pos == 1 and $obj->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		$sink->emit('a');
		return;
	} elsif ($obj->isa('RDF::Trine::Node::Blank') and $pos == 0) {
		if (my $model = $args{ model }) {
			my $count	= $model->count_statements( undef, undef, $obj );
			my $rec		= $model->count_statements( $obj, undef, $obj );
			# XXX if $count == 1, then it would be better to ignore this triple for now, since it's a 'single-owner' bnode, and better serialized as a '[ ... ]' bnode in the object position as part of the 'owning' triple
			if ($count < 1 and $rec == 0) {
				$sink->emit('[]');
				return;
			}
		}
	} elsif (defined(my $str = $self->__node_concise_string( $obj ))) {
		$sink->emit($str);
		return;
	}
	
	$sink->emit($obj->as_ntriples);
	return;
}

__PACKAGE__->meta->make_immutable;
1;
