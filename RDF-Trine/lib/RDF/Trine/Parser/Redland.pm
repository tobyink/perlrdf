# RDF::Trine::Parser::Redland
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Redland - RDF Parser using the Redland library

=head1 VERSION

This document describes RDF::Trine::Parser::Redland version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 use RDF::Trine::Parser::Redland; # to overwrite internal dispatcher

 # Redland does turtle, ntriples, trig and rdfa as well
 my $parser = RDF::Trine::Parser->new( 'rdfxml' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::Redland;

use strict;
use warnings;
no warnings 'redefine';

use Carp;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

#use RDF::Trine qw(literal);
#use RDF::Trine::Statement::Triple;
#use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $HAVE_REDLAND_PARSER, %FORMATS);
BEGIN {
	%FORMATS = (
	rdfxml	 => [
					'RDF::Trine::Parser::Redland::RDFXML',
					'http://www.w3.org/ns/formats/RDF_XML',
					[qw(application/rdf+xml)],
					[qw(rdf xrdf rdfx)]
				],
	ntriples => [
					'RDF::Trine::Parser::Redland::NTriples',
					'http://www.w3.org/ns/formats/data/N-Triples',
					[qw(text/plain)],
					[qw(nt)]
				],
	turtle	 => [
					'RDF::Trine::Parser::Redland::Turtle',
					'http://www.w3.org/ns/formats/Turtle',
					[qw(application/x-turtle application/turtle text/turtle)],
					[qw(ttl)]
				],
	trig	 => [
					'RDF::Trine::Parser::Redland::Trig',
					undef,
					[],
					[qw(trig)]
				],
	librdfa	 => [
					'RDF::Trine::Parser::Redland::RDFa',
					'http://www.w3.org/ns/formats/data/RDFa',
					[], #[qw(application/xhtml+xml)],
					[], #[qw(html xhtml)]
				],
	);
	
	$VERSION	= '1.000';
#	for my $format (keys %FORMATS) {
#		$RDF::Trine::Parser::parser_names{$format} = $FORMATS{$format}[0];
#		$RDF::Trine::Parser::format_uris{ $FORMATS{$format}[1] } = $FORMATS{$format}[0]
#			if defined $FORMATS{$format}[1];
#		map { $RDF::Trine::Parser::media_types{$_} = $FORMATS{$format}[0] }
#			(@{$FORMATS{$format}[2]});
#		map { $RDF::Trine::Parser::file_extensions{$_} = $FORMATS{$format}[0] }
#			(@{$FORMATS{$format}[3]});
#	}
	
	unless ($ENV{RDFTRINE_NO_REDLAND}) {
		eval "use RDF::Redland 1.000701;";
		unless ($@) {
			$HAVE_REDLAND_PARSER	= 1;
		}
	}
}

######################################################################

=item C<< new ( options => \%options ) >>

Returns a new Redland parser object with the supplied options. Use the
C<name> option to tell Redland which parser it should use.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	unless ($HAVE_REDLAND_PARSER) {
		throw RDF::Trine::Error
			-text => "Failed to load RDF::Redland >= 1.0.7.1";
	}
	unless (defined $args{name}) {
		throw RDF::Trine::Error
			-text => "Redland parser needs to know which format it's parsing!";
	}
	unless ($FORMATS{$args{name}}) {
		throw RDF::Trine::Error
			-text => "Unrecognized format name $args{name} for Redland parser";
	}
	
	my $parser	= RDF::Redland::Parser->new($args{name}) or
		throw RDF::Trine::Error
			-text => "Could not load a Redland $args{name} parser.";
	
	#warn "sup dawgs";

	my $self = bless( { %args }, $class);
	return $self;
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
	my $handler = shift;
	
	my $parser	= RDF::Redland::Parser->new($self->{name});
	
	my $null_base	= 'urn:uuid:1d1e755d-c622-4610-bae8-40261157687b';
	if ($base and blessed($base) and $base->isa('URI')) {
		$base	= $base->as_string;
	}
	$base		= RDF::Redland::URI->new(defined $base ? $base : $null_base);
	my $stream	= eval {
		$parser->parse_string_as_stream($string, $base)
	};
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => $@;
	}
	
	while ($stream and !$stream->end) {
		#my $context = $stream->context;
		#warn $context;
		my $stmt = RDF::Trine::Statement::API->from_redland($stream->current);
		if ($self->{canonicalize}) {
			my $o = $stmt->object;
			# basically copied from RDF::Trine::Parser::Turtle
			if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
				$stmt->object($o->canonicalize);
			}
		}

		# run handler
		$handler->($stmt) if ($handler and reftype($handler) eq 'CODE');

		$stream->next;
	}
	undef $stream;
	
	if (my $map = $self->{ namespaces }) {
		my %seen	= $parser->namespaces_seen;
		while (my ($ns, $uri) = each(%seen)) {
			$map->add_mapping( $ns => $uri->as_string );
		}
	}
	return;
}

######################################################################

package RDF::Trine::Parser::Turtle::Redland;
use Moose;
use constant media_types => [ 'application/x-turtle', 'application/turtle', 'text/turtle' ];
use RDF::Trine::FormatRegistry '-register_parser';
use constant redland_parser_format => 'turtle';
with ('RDF::Trine::Parser::API', 'RDF::Trine::Parser::API::Redland');

######################################################################

package RDF::Trine::Parser::RDFXML::Redland;
no warnings 'redefine';
use Moose;
use constant media_types => [ 'application/rdf+xml', 'application/octet-stream', ];
use RDF::Trine::FormatRegistry '-register_parser';
use constant redland_parser_format => 'rdfxml';
with ('RDF::Trine::Parser::API', 'RDF::Trine::Parser::API::Redland');

######################################################################

package RDF::Trine::Parser::NTriples::Redland;
no warnings 'redefine';
use Moose;
use constant media_types => [ 'text/plain' ];
use RDF::Trine::FormatRegistry '-register_parser';
use constant redland_parser_format => 'ntriples';
with ('RDF::Trine::Parser::API', 'RDF::Trine::Parser::API::Redland');

######################################################################

package RDF::Trine::Parser::Trig::Redland;
use Moose;
use constant media_types => [ 'application/x-trig' ];
use RDF::Trine::FormatRegistry '-register_parser';
use constant redland_parser_format => 'trig';
with ('RDF::Trine::Parser::API', 'RDF::Trine::Parser::API::Redland');

######################################################################

package RDF::Trine::Parser::RDFa::Redland;
use Moose;
use constant media_types => [ 'application/xhtml+xml' ];
use RDF::Trine::FormatRegistry '-register_parser';
use constant redland_parser_format => 'trig';
with ('RDF::Trine::Parser::API', 'RDF::Trine::Parser::API::Redland');


1;

__END__

=back

=head1 ENVIRONMENT VARIABLES

Set C<RDFTRINE_NO_REDLAND> to something true to disable the Redland parsers.

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
