# RDF::Trine::Parser::RDFJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFJSON - RDF/JSON RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFJSON version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::RDFJSON;

use Moose;
#no warnings 'redefine';
#no warnings 'once';

use constant media_types => (
    'application/json',
    'application/x-rdf+json',
);

use RDF::Trine::FormatRegistry '-register_parser';

use URI;
use Log::Log4perl;

use RDF::Trine::Statement::Triple;
use RDF::Trine::Namespace;
use RDF::Trine::Error;
use TryCatch;

use Scalar::Util qw(blessed looks_like_number);
use JSON;

with ('RDF::Trine::Parser::API');

our ($VERSION, $rdf, $xsd);
our ($r_boolean, $r_comment, $r_decimal, $r_double, $r_integer, $r_language, $r_lcharacters, $r_line, $r_nameChar_extra, $r_nameStartChar_minus_underscore, $r_scharacters, $r_ucharacters, $r_booltest, $r_nameStartChar, $r_nameChar, $r_prefixName, $r_qname, $r_resource_test, $r_nameChar_test);
BEGIN {
	$VERSION				= '1.000';
}

=item C<< new >>

Returns a new RDFJSON parser.

=cut

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

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
	my $context	= $args{'context'};
	my $opts	= $args{'json_opts'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	return $self->parse( $uri, $input, $handler, $opts );
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $handler	= shift;
	my $opts	= shift;

	$self->_parse_graph($input, $handler, $uri, $$opts);
}

sub _parse_bindings {
    my $self = shift;
    $self->_graph_to_bindings( $self->_parse_graph( @_ ) );
}

sub _parse_graph {
	my $self	= shift;
	my $input	= shift;
	my $handler	= shift;
	my $uri		= shift;
	my $opts	= shift;
	
	my $index	= eval { from_json($input, $opts) };
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => "$@";
	}
	
	foreach my $s (keys %$index) {
		my $ts = ( $s =~ /^_:(.*)$/ ) ?
		         RDF::Trine::Node::Blank->new($self->bnode_prefix . $1) :
					RDF::Trine::Node::Resource->new($s, $uri);
		
		foreach my $p (keys %{ $index->{$s} }) {
			my $tp = RDF::Trine::Node::Resource->new($p, $uri);
			
			foreach my $O (@{ $index->{$s}->{$p} }) {
				my $to;
				
				# $O should be a hashref, but we can do a little error-correcting.
				unless (ref $O) {
					if ($O =~ /^_:/) {
						$O = { 'value'=>$O, 'type'=>'bnode' };
					} elsif ($O =~ /^[a-z0-9._\+-]{1,12}:\S+$/i) {
						$O = { 'value'=>$O, 'type'=>'uri' };
					} elsif ($O =~ /^(.*)\@([a-z]{2})$/) {
						$O = { 'value'=>$1, 'type'=>'literal', 'lang'=>$2 };
					} else {
						$O = { 'value'=>$O, 'type'=>'literal' };
					}
				}
				
				if (lc $O->{'type'} eq 'literal') {
					$to = RDF::Trine::Node::Literal->new(
						$O->{'value'}, $O->{'lang'}, $O->{'datatype'});
				} else {
					$to = ( $O->{'value'} =~ /^_:(.*)$/ ) ?
						RDF::Trine::Node::Blank->new($self->bnode_prefix . $1) :
						RDF::Trine::Node::Resource->new($O->{'value'}, $uri);
				}
				
				if ( $ts && $tp && $to ) {
					if ($self->canonicalize) {
						if ($to->isa('RDF::Trine::Node::Literal') and $to->has_datatype) {
							my $value	= $to->literal_value;
							my $dt		= $to->literal_datatype;
							my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
							$to	= RDF::Trine::Node::Literal->new( $canon, undef, $dt );
						}
					}
					my $st = RDF::Trine::Statement::Triple->new($ts, $tp, $to);
					$handler->($st);
				}
			}
		}
	}
	
	return;
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
