# RDF::Query::Plan::Quad
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Quad - Executable query plan for Quads.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Quad;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( @quad ) >>

=cut

sub new {
	my $class	= shift;
	my @quad	= @_;
	my $self	= $class->SUPER::new( @quad );
	
	### the next two loops look for repeated variables because some backends
	### (Redland and RDF::Core) can't distinguish a pattern like { ?a ?a ?b }
	### from { ?a ?b ?c }. if we find repeated variables (there can be at most
	### two since there are only four nodes in a quad), we save the positions
	### in the quad that hold the variable(s), and the code in next() will filter
	### out any results that don't have the same value in those positions.
	###
	### in the first pass, we also set up the mapping that will let us pull out
	### values from the result quads to construct result bindings.
	
	my %var_to_position;
	my @methodmap	= qw(subject predicate object context);
	my %counts;
	my @dup_vars;
	foreach my $idx (0 .. 3) {
		my $node	= $quad[ $idx ];
		if (blessed($node) and $node->isa('RDF::Trine::Node::Variable')) {
			my $name	= $node->name;
			$var_to_position{ $name }	= $methodmap[ $idx ];
			$counts{ $name }++;
			if ($counts{ $name } >= 2) {
				push(@dup_vars, $name);
			}
		}
	}
	
	my %positions;
	if (@dup_vars) {
		foreach my $dup_var (@dup_vars) {
			foreach my $idx (0 .. 3) {
				my $var	= $quad[ $idx ];
				if (blessed($var) and ($var->isa('RDF::Trine::Node::Variable') or $var->isa('RDF::Trine::Node::Blank'))) {
					my $name	= ($var->isa('RDF::Trine::Node::Blank')) ? '__' . $var->blank_identifier : $var->name;
					if ($name eq $dup_var) {
						push(@{ $positions{ $dup_var } }, $methodmap[ $idx ]);
					}
				}
			}
		}
	}
	
	$self->[0]{mappings}	= \%var_to_position;
	
	if (%positions) {
		$self->[0]{dups}	= \%positions;
	}
	
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "QUAD plan can't be executed while already open";
	}
	my @quad	= @{ $self }[ 1..4 ];
	my $bound	= $context->bound;
	if (%$bound) {
		foreach my $i (0 .. $#quad) {
			next unless ($quad[$i]->isa('RDF::Trine::Node::Variable'));
			next unless (blessed($bound->{ $quad[$i]->name }));
			$quad[ $i ]	= $bound->{ $quad[$i]->name };
		}
	}
	
	my $bridge	= $context->model;
	my $iter	= $bridge->get_named_statements( @quad, $context->query, $context->bound );
	
	if (blessed($iter)) {
		$self->[0]{iter}	= $iter;
		$self->[0]{bound}	= $bound;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open QUAD";
	}
	my $iter	= $self->[0]{iter};
	LOOP: while (my $row = $iter->next) {
		if (my $data = $self->[0]{dups}) {
			foreach my $pos (values %$data) {
				my @pos	= @$pos;
				my $first_method	= shift(@pos);
				my $first			= $row->$first_method();
				foreach my $p (@pos) {
					unless ($first->equal( $row->$p() )) {
						next LOOP;
					}
				}
			}
		}
		
		my $binding	= {};
		foreach my $key (keys %{ $self->[0]{mappings} }) {
			my $method	= $self->[0]{mappings}{ $key };
			$binding->{ $key }	= $row->$method();
		}
		my $pre_bound	= $self->[0]{bound};
		my $bindings	= RDF::Query::VariableBindings->new( $binding );
		@{ $bindings }{ keys %$pre_bound }	= values %$pre_bound;
		return $bindings;
	}
	return;
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open QUAD";
	}
	delete $self->[0]{iter};
	delete $self->[0]{bound};
	$self->SUPER::close();
}

=item C<< nodes () >>

=cut

sub nodes {
	my $self	= shift;
	return @{ $self }[1,2,3,4];
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $bf		= '';
	foreach my $n (@{ $self }[1,2,3,4]) {
		$bf		.= ($n->isa('RDF::Trine::Node::Variable'))
				? 'f'
				: 'b';
	}
	return $bf;
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return [];
}

=item C<< sse ( \%context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf("(quad %s %s %s %s)", map { $_->sse( $context, "${indent}${more}" ) } @{ $self }[1..4]);
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
