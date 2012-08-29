# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class

=head1 VERSION

This document describes RDF::Trine::Parser version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 
 RDF::Trine::Parser->parse_url_into_model( $url, $model );
 
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $rdf, $model );
 
 $parser->parse_file_into_model( $base_uri, 'data.ttl', $model );

=head1 DESCRIPTION

RDF::Trine::Parser is a base class for RDF parsers. It may be used as a factory
class for constructing parser objects by name or media type with the C<< new >>
method, or used to abstract away the logic of choosing a parser based on the
media type of RDF content retrieved over the network with the
C<< parse_url_into_model >> method.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser;

use strict;
use warnings;
#no warnings 'redefine';

use Data::Dumper;
use Encode qw(decode);
use LWP::MediaTypes;
use Module::Load::Conditional qw[can_load];

sub media_types {
	RDF::Trine::FormatRegistry->instance->known_media_types_with_serializers
}


our ($VERSION);
our %file_extensions;
our %parser_names;
our %canonical_media_types;
our %media_types;
our %format_uris;
our %encodings;

BEGIN {
	$VERSION	= '1.000';
	can_load( modules => {
		'Data::UUID'	=> undef,
		'UUID::Tiny'	=> undef,
	} );
}

use Scalar::Util qw(blessed);
use LWP::UserAgent;

use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser::NTriples;
use RDF::Trine::Parser::NQuads;
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::Turtle::Redland;
use RDF::Trine::Parser::TriG;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;
use RDF::Trine::Parser::RDFa;

=item C<< parser_by_media_type ( $media_type ) >>

Returns the parser class appropriate for parsing content of the specified media type.

=cut

sub parser_by_media_type {
	my $proto	= shift;
	my $type	= shift;
	my $class	= $media_types{ $type };
	return $class;
}

=item C<< guess_parser_by_filename ( $filename ) >>

Returns the best-guess parser class to parse a file with the given filename.

=cut

sub guess_parser_by_filename {
	my $class	= shift;
	my $file	= shift;
	if ($file =~ m/[.](\w+)$/) {
		my $ext	= $1;
		return $file_extensions{ $ext } if exists $file_extensions{ $ext };
	}
	return $class->parser_by_media_type( 'application/rdf+xml' ) || 'RDF::Trine::Parser::RDFXML';
}

=item C<< new ( $parser_name, @args ) >>

Returns a new RDF::Trine::Parser object for the parser with the specified name
(e.g. "rdfxml" or "turtle"). If no parser with the specified name is found,
throws a RDF::Trine::Error::ParserError exception.

Any C<< @args >> will be passed through to the format-specific parser
constructor.

If C<< @args >> contains the key-value pair C<< (canonicalize => 1) >>, literal
value canonicalization will be attempted during parsing with warnings being
emitted for invalid lexical forms for recognized datatypes.

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	my $key		= lc($name);
	$key		=~ s/[^a-z]//g;

	if ($name eq 'guess') {
		throw RDF::Trine::Error::UnimplementedError -text => "guess parser heuristics are not implemented yet";
	} elsif (my $class = $parser_names{ $key }) {
		# re-add name for multiformat (e.g. Redland) parsers
		return $class->new( name => $key, @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "No parser known named $name";
	}
}


=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut




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
