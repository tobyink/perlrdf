# RDF::Trine::Node::Literal
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Literal - RDF Node class for literals

=cut

package RDF::Trine::Node::Literal;

use strict;
use warnings;
use base qw(RDF::Trine::Node);

use RDF::Trine::Error;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $string, $lang, $datatype )>

Returns a new Literal structure.

=cut

sub new {
	my $class	= shift;
	my $literal	= shift;
	my $lang	= shift;
	my $dt		= shift;
	my $self;
	
	throw RDF::Trine::Error::MethodInvocationError ( -text => "Literal values cannot have both language and datatype" ) if ($lang and $dt);
	if ($lang) {
		$self	= [ 'LITERAL', $literal, lc($lang), undef ];
	} elsif ($dt) {
		$self	= [ 'LITERAL', $literal, undef, $dt ];
	} else {
		$self	= [ 'LITERAL', $literal ];
	}
	bless($self, $class);
}

=item C<< literal_value >>

Returns the string value of the literal.

=cut

sub literal_value {
	my $self	= shift;
	return $self->[1];
}

=item C<< literal_value_language >>

Returns the language tag of the ltieral.

=cut

sub literal_value_language {
	my $self	= shift;
	return $self->[2];
}

=item C<< literal_datatype >>

Returns the datatype of the literal.

=cut

sub literal_datatype {
	my $self	= shift;
	return $self->[3];
}

=item C<< sse >>

Returns the SSE string for this literal.

=cut

sub sse {
	my $self	= shift;
	my $literal	= $self->[1];
	my $lang	= $self->[2];
	my $dt		= $self->[3];
	$literal	=~ s/"/\\"/g;
	if ($lang) {
		return qq("${literal}"\@${lang});
	} elsif ($dt) {
		return qq("${literal}"^^<${dt}>);
	} else {
		return qq("${literal}");
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	my $string	= '"' . $self->literal_value . '"';
	if ($self->has_datatype) {
		$string	.= '^^<' . $self->literal_datatype . '>';
	} elsif ($self->has_language) {
		$string	.= '@' . $self->literal_value_language;
	}
	return $string;
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'LITERAL';
}

=item C<< has_language >>

Returns true if this literal is language-tagged, false otherwise.

=cut

sub has_language {
	my $self	= shift;
	return defined($self->literal_value_language);
}

=item C<< has_datatype >>

Returns true if this literal is datatyped, false otherwise.

=cut

sub has_datatype {
	my $self	= shift;
	return defined($self->literal_datatype);
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node'));
	return 0 unless ($self->type eq $node->type);
	return 0 unless ($self->literal_value eq $node->literal_value);
	if ($self->literal_datatype or $node->literal_datatype) {
		no warnings 'uninitialized';
		return 0 unless ($self->literal_datatype eq $node->literal_datatype);
	}
	if ($self->literal_value_language or $node->literal_value_language) {
		no warnings 'uninitialized';
		return 0 unless ($self->literal_value_language eq $node->literal_value_language);
	}
	return 1;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut