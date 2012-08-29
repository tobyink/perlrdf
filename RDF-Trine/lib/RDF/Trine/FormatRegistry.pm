package RDF::Trine::FormatRegistry;

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types::Moose qw(Str ArrayRef Any Bool ClassName Object);
use RDF::Trine::Types qw(UriStr TrineFormat);
use namespace::autoclean;

use RDF::Trine::Format;

sub import {
	my ($class, $cmd, @args) = @_;
	
	my $registry = $class->instance;
	
	if ($cmd eq '-format') {
		$registry->register_format(
			'RDF::Trine::Format'->new(@args),
		);
	}
	
	if ($cmd eq '-register_parser') {
		my $parser = caller;
		my $format;
		MT: for my $mt (@{ $parser->media_types }) {
			FMT: for my $fmt (@{ $registry->formats }) {
				if ($fmt->handles_media_type($mt)) {
					$format = $fmt;
					last MT;
				}
			}
		}
		confess "No known formats with media types: "
			. join(q[ ], @{ $parser->media_types });
		$format->register_parser($parser);
	}
	
	if ($cmd eq '-register_serializer') {
		my $serializer = caller;
		my $format;
		MT: for my $mt (@{ $serializer->media_types }) {
			FMT: for my $fmt (@{ $registry->formats }) {
				if ($fmt->handles_media_type($mt)) {
					$format = $fmt;
					last MT;
				}
			}
		}
		confess "No known formats with media types: "
			. join(q[ ], @{ $serializer->media_types });
		$format->register_serializer($serializer);
	}
}

class_has instance => (
	is         => 'ro',
	isa        => Object,
	default    => sub { __PACKAGE__->new },
);

has formats => (
	is         => 'ro',
	isa        => ArrayRef[ TrineFormat ],
	traits     => ['Array'],
	lazy_build => 1,
	handles    => {
		all_formats     => 'elements',
		filter_formats  => 'grep',
		_add_format     => 'push',
	},
);

sub register_format {
	my ($self, $f) = @_;
	my @existing = $self->filter_formats(sub { $_->format_uri eq $f->format_uri });
	$self->_add_format($f) unless @existing;
	push @existing, $f;
	return $existing[0];
}

sub find_format {
	my ($self, $key, $opts) = @_;
	$opts //= {};
	$self->find_format_by_uri($key, $opts)         or
	$self->find_format_by_media_type($key, $opts)  or
	$self->find_format_by_name($key, $opts)
}

sub find_format_by_uri {
	my ($self, $u, $opts) = @_;
	$u      = UriStr->coerce($u);
	$opts //= {};
	my @f = $self->filter_formats(sub {
		my $f = $_;
		$f->format_uri eq $u and $f->matches_opts($opts)
	});
	return unless @f;
	return(wantarray ? @f : $f[0]);
}

sub find_format_by_media_type {
	my ($self, $mt, $opts) = @_;
	$opts //= {};
	my @f = $self->filter_formats(sub {
		my $f = $_;
		$f->handles_media_type($mt) and $f->matches_opts($opts)
	});
	return unless @f;
	return(wantarray ? @f : $f[0]);
}

sub find_format_by_name {
	my ($self, $n, $opts) = @_;
	$opts //= {};
	my @f = $self->filter_formats(sub {
		my $f = $_;
		(grep { $n eq $_ } @{ $f->names }) and $f->matches_opts($opts)
	});
	return unless @f;
	return(wantarray ? @f : $f[0]);
}

sub find_format_by_capabilities {
	my ($self, $opts) = @_;
	$opts //= {};
	my @f = $self->filter_formats(sub { $_->matches_opts($opts) });
	return unless @f;
	return(wantarray ? @f : $f[0]);
}

sub _build_formats {
	my $self = shift;
	
	require RDF::Trine::Format;
	my $fc   = 'RDF::Trine::Format';
	
	[
		$fc->new(
			names         => [qw( RDF/XML RDFXML )],
			format_uri    => 'http://www.w3.org/ns/formats/RDF_XML',
			media_types   => [qw( application/rdf+xml application/octet-stream )],
			extensions    => [qw( rdf xrdf rdfx )],
			magic_numbers => [qr{ <rdf:RDF }x],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( Turtle )],
			format_uri    => 'http://www.w3.org/ns/formats/Turtle',
			media_types   => [qw( text/turtle application/turtle application/x-turtle )],
			extensions    => [qw( ttl turtle )],
			magic_numbers => [qr{ \@prefix }x, qr{ \@base }x],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( N-Triples NTriples )],
			format_uri    => 'http://www.w3.org/ns/formats/N-Triples',
			media_types   => [qw( text/plain )],
			extensions    => [qw( nt )],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( XHTML+RDFa RDFa )],
			format_uri    => 'http://www.w3.org/ns/formats/RDFa',
			media_types   => [qw( application/xhtml+xml )],
			extensions    => [qw( xhtml )],
			magic_numbers => [qr{ xmlns="http://www\.w3\.org/1999/xhtml" }x],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( HTML+RDFa )],
			format_uri    => 'tag:cpan.org,2012:tobyink:format:HTMLRDFa',
			media_types   => [qw( text/html )],
			extensions    => [qw( html )],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( RDF/JSON RDFJSON )],
			format_uri    => 'tag:cpan.org,2012:tobyink:format:RDFJSON',
			media_types   => [qw( application/x-rdf+json )],
			extensions    => [qw( json )],
			triples       => 1,
		),
		$fc->new(
			names         => [qw( TriG )],
			format_uri    => 'tag:cpan.org,2012:tobyink:format:TriG',
			media_types   => [qw( application/x-trig )],
			extensions    => [qw( trig )],
			triples       => 1,
			quads         => 1,
		),
		$fc->new(
			names         => [qw( N-Quads NQuads )],
			format_uri    => 'http://sw.deri.org/2008/07/n-quads/#n-quads',
			media_types   => [qw( text/x-nquads )],
			extensions    => [qw( nq )],
			triples       => 1,
			quads         => 1,
		),
		$fc->new(
			names         => ['OWL Functional Syntax', qw( OwlFn )],
			format_uri    => 'http://www.w3.org/ns/formats/OWL_Functional',
			media_types   => [qw( text/x-nquads )],
			extensions    => [qw( nq )],
			triples       => 1,
			quads         => 1,
		),
		$fc->new(
			names         => ['OWL Functional Syntax', qw( OwlFn )],
			format_uri    => 'http://www.w3.org/ns/formats/OWL_Functional',
			media_types   => [qw( text/owl-functional )],
			extensions    => [qw( ofn )],
			triples       => 1,
		),
		$fc->new(
			names         => ['OWL XML', qw( OWLXML )],
			format_uri    => 'http://www.w3.org/ns/formats/OWL_XML',
			media_types   => [qw( application/owl+xml )],
			extensions    => [qw( owx owlx )],
			magic_numbers => [qr{ xmlns="http://www\.w3\.org/2002/07/owl." }x],
			triples       => 1,
		),
		$fc->new(
			names         => ['SPARQL Results in XML'],
			format_uri    => 'http://www.w3.org/ns/formats/SPARQL_Results_XML',
			media_types   => [qw( application/sparql-results+xml )],
			extensions    => [qw( srx xml )],
			magic_numbers => [qr{ xmlns="http://www\.w3\.org/2005/sparql-results." }x],
			triples       => 1,
			quads         => 1,
			result_sets   => 1,
			booleans      => 1,
		),
		$fc->new(
			names         => ['SPARQL Results in JSON'],
			format_uri    => 'http://www.w3.org/ns/formats/SPARQL_Results_JSON',
			media_types   => [qw( application/sparql-results+json )],
			extensions    => [qw( srj )],
			triples       => 1,
			quads         => 1,
			result_sets   => 1,
			booleans      => 1,
		),
		$fc->new(
			names         => ['SPARQL Results in CSV'],
			format_uri    => 'http://www.w3.org/ns/formats/SPARQL_Results_CSV',
			media_types   => [qw( text/csv )],
			extensions    => [qw( csv )],
			triples       => 1,
			quads         => 1,
			result_sets   => 1,
			booleans      => 1,
		),
		$fc->new(
			names         => ['SPARQL Results in TSV'],
			format_uri    => 'http://www.w3.org/ns/formats/SPARQL_Results_TSV',
			media_types   => [qw( text/tab-separated-values )],
			extensions    => [qw( tsv tab )],
			triples       => 1,
			quads         => 1,
			result_sets   => 1,
			booleans      => 1,
		),
	]
}

1;