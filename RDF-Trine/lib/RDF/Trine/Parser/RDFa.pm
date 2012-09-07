# RDF::Trine::Parser::RDFa
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFa - RDFa Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFa version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'rdfxml' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::RDFa;

use Moose;

with ('RDF::Trine::Parser::API');

use constant media_types => (
    'application/xhtml+xml',
    'text/html',
);
use RDF::Trine::FormatRegistry '-register_parser';

use Carp;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);
use Module::Load::Conditional qw[can_load];

use RDF::Trine::Error;
use TryCatch;
use IO::String;

######################################################################

our ($VERSION, $HAVE_RDFA_PARSER);
BEGIN {
	$VERSION	= '1.000';
	if (can_load( modules => { 'RDF::RDFa::Parser' => 0.30 })) {
		$HAVE_RDFA_PARSER	= 1;
	}
}

######################################################################

=item C<< new ( options => \%options ) >>

Returns a new RDFa parser object with the supplied options.

=cut

sub BUILD {
	my $self	= shift;
	unless ($HAVE_RDFA_PARSER) {
		throw RDF::Trine::Error -text => "Failed to load RDF::RDFa::Parser >= 0.30";
	}
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;

	my $fh = (ref $string) ? $string : IO::String->new($string);
	return $self->_parse_graph($fh, $handler, $base, @_);
}

sub _parse_bindings {
    my $self = shift;
    return $self->_graph_to_bindings( $self->_parse_graph( @_ ) );
}

sub _parse_graph {
	my $self	= shift;
	my $fh   	= shift;
	my $handler	= shift;
	my $base	= shift;

	my $string = do { local $/; <$fh> };
	
	my $parser  = RDF::RDFa::Parser->new($string, $base, $self->{'options'});
	$parser->set_callbacks({
		ontriple	=> sub {
			my ($p, $el, $st)	= @_;
			if (reftype($handler) eq 'CODE') {
				if ($self->{canonicalize}) {
					my $o	= $st->object;
					if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
						my $value	= $o->literal_value;
						my $dt		= $o->literal_datatype;
						my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
						$o	= RDF::Trine::Node::Literal->new( $canon, undef, $dt );
						$st->object( $o );
					}
				}
				$handler->( $st );
			}
			return 1;
		}
	});
	$parser->consume;
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
