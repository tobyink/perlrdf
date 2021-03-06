# RDF::Trine::Parser::NQuads
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NQuads - N-Quads Parser

=head1 VERSION

This document describes RDF::Trine::Parser::NQuads version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'nquads' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::NQuads;

use Moose;
use utf8;

use Carp;
use Encode qw(decode);
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

use RDF::Trine qw(literal);
use RDF::Trine::Statement::Triple;
use RDF::Trine::Error;
use TryCatch;
use constant media_types => (
    'text/x-nquads',
);

extends 'RDF::Trine::Parser::NTriples';

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.000';
}

######################################################################

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
or quad parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $proto	= shift;
	my $self	= blessed($proto) ? $proto : $proto->new();
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $input	= shift;
	my $model	= shift;
	my %args	= @_;
	
	if (my $context = $args{'context'}) {
		throw RDF::Trine::Error::ParserError -text => "Cannot pass a context node to N-Quads parse_into_model method";
	}
	
	my $handler	= sub {
		my $st	= shift;
		$model->add_statement( $st );
	};

    # ensure that _parse_graph/_parse_bindings gets an iterator
	my $fh = (ref $input) ? $input : IO::String->new($input);

	return $self->_parse_graph( $fh, $handler, $uri );
}

sub _parse_bindings {
    # TODO
}

sub _emit_statement {
	my $self	= shift;
	my $handler	= shift;
	my $nodes	= shift;
	my $lineno	= shift;
	my $st;
	
	if ($self->canonicalize) {
		if ($nodes->[2]->isa('RDF::Trine::Node::Literal') and $nodes->[2]->has_datatype) {
			$nodes->[2] = $nodes->[2]->canonicalize;
		}
	}

	if (scalar(@$nodes) == 3) {
		$st	= RDF::Trine::Statement::Triple->new( @$nodes );
	} elsif (scalar(@$nodes) == 4) {
		$st	= RDF::Trine::Statement::Quad->new( @$nodes );
	} else {
		throw RDF::Trine::Error::ParserError -text => qq[Not valid N-Quads data at line $lineno];
	}
	
	$handler->( $st );
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
