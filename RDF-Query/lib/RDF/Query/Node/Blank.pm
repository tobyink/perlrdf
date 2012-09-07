# RDF::Query::Node::Blank
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Blank - RDF Node class for blank nodes

=head1 VERSION

This document describes RDF::Query::Node::Blank version 2.908.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Node> and L<RDF::Trine::Node::Blank> classes.

=over 4

=cut

package RDF::Query::Node::Blank;

use strict;
use warnings;
no warnings 'redefine';
use Moose;
extends 'RDF::Trine::Node::Blank';

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.908';
}

######################################################################

my $COUNTER	= 0;
has '+value' => (
	default => sub { 'r' . time() . 'r' . $COUNTER++; }
);

use overload	'<=>'	=> \&_cmp,
				'cmp'	=> \&_cmp,
				'<'		=> sub { _cmp(@_[0,1]) == -1 },
				'>'		=> sub { _cmp(@_[0,1]) == 1 },
				'!='	=> sub { _cmp(@_[0,1]) != 0 },
				'=='	=> sub { _cmp(@_[0,1]) == 0 },
				'+'		=> sub { $_[0] },
				'""'	=> sub { $_[0]->sse },
			;

sub _cmp {
	my $nodea	= shift;
	my $nodeb	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.node.blank");
	$l->debug("blank comparison: " . Dumper($nodea, $nodeb));
	return 1 unless blessed($nodeb);
	return -1 if ($nodeb->isa('RDF::Query::Node::Literal'));
	return -1 if ($nodeb->isa('RDF::Query::Node::Resource'));
	return 1 unless ($nodeb->isa('RDF::Query::Node::Blank'));
	my $cmp	= $nodea->blank_identifier cmp $nodeb->blank_identifier;
	$l->debug("-> $cmp");
	return $cmp;
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> 'node',
		blank		=> $self->blank_identifier,
	};
}

=item C<< make_distinguished_variable >>

Returns a new variable based on this blank node.

=cut

sub make_distinguished_variable {
	my $self	= shift;
	my $id		= $self->blank_identifier;
	my $name	= '__ndv_' . $id;
	my $var		= RDF::Query::Node::Variable->new( $name );
	return $var;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
