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
                    $format->register_parser($parser);
					last MT;
				}
			}
		}
		confess "No known formats with media types: "
			. join(q[ ], @{ $parser->media_types })
			unless $format;
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
			. join(q[ ], @{ $serializer->media_types })
			unless $format;
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

sub __canon
{
	my $_ = lc shift;
	s/[^a-z0-9]//g;
	$_;
}

sub find_format_by_name {
	my ($self, $n, $opts) = @_;
	$opts //= {};
	my @f = $self->filter_formats(sub {
		my $f = $_;
		(grep { my $x=$_; __canon($n) eq __canon($x) } @{ $f->names }) and $f->matches_opts($opts)
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

sub known_media_types {
	my $self = shift;
	return
		map  { @{ $_->media_types } }
		$self->all_formats;
}

sub known_media_types_with_parsers {
	my $self = shift;
	return
		map  { @{ $_->media_types } }
		grep { defined $_->parsers->[0] }
		$self->all_formats;
}

sub known_media_types_with_serializers {
	my $self = shift;
	return
		map  { @{ $_->media_types } }
		grep { defined $_->serializers->[0] }
		$self->all_formats;
}

sub http_negotiate
{
	my ($self, $opts) = @_;
	my @formats =
		grep { defined $_->serializers->[0] }
		$self->find_format_by_capabilities($opts);
	my @http;
	foreach my $fmt (@formats) {
		my $qs = 0.9;
		$qs = 1.0 if $fmt eq 'SPARQL Results in XML';
		$qs = 1.0 if $fmt eq 'RDF/XML';
		foreach my $mt ($fmt->all_media_types) {
			my $mtqs = $qs;
			$mtqs = 0.1 if $mt =~ m{/x-};
			push @http => [ $fmt->name, $mtqs, $mt ];
		}
	}
	return \@http;
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
			media_types   => [qw( text/plain text/x-ntriples )],
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
			media_types   => [qw( application/x-rdf+json application/json )],
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

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

RDF::Trine::FormatRegistry - file formats that RDF::Trine knows about

=head DESCRIPTION

RDF::Trine::FormatRegistry keeps a list of file formats that RDF::Trine is
aware of. A registry is an object, and you can make your own registry like
this:

  my $reg = RDF::Trine::FormatRegistry->new(formats => \@list);

... but most places in Trine just assume the use of the default format
registry object, which can be accessed like this:

  my $reg = RDF::Trine::FormatRegistry->instance;

When parser and serializer modules are loaded, they will attempt to
register themselves with the format registry like this:

  use RDF::Trine::FormatRegistry -format => {
    format_uri  => 'http://www.example.com/monkey-rdf',
    names       => ['Monkey RDF'],
    media_types => [qw(text/x-monkey)],
  };
  
  package My::Parser::Monkey;
  use constant media_types => [qw(text/x-monkey)];
  use RDF::Trine::FormatRegistry -register_parser;
  
  package My::Serializer::Monkey;
  use constant media_types => [qw(text/x-monkey)];
  use RDF::Trine::FormatRegistry -register_serializer;

You can then find parsers and serializers from the registry:

  my $p = $reg->find_format_by_media_type('text/x-monkey')->parsers->[0];

The factory classes L<RDF::Trine::Parser> and L<RDF::Trine::Serializer> provide
some convenient shortcuts for this.

=head2 Class Attributes

=over

=item C<< instance >>

The default instance.

=back

=head2 Attributes

=over

=item C<< formats >>

The list of known formats, as an arrayref.

=back

=head2 Methods

=over

=item C<< all_formats >>

The list of known formats, as a list.

=item C<< filter_formats($coderef)>>

Grep the list of known formats.

=item C<< register_format($format) >>

Registers an L<RDF::Trine::Format> unless it already exists.

=item C<< find_format($search_key, \%features) >>

Searches for a format matching the search key which may be a format URI,
a media type or a format name. The features hash keys allow you to indicate
which format features you consider necessary. Possible keys are:

=over

=item * triples

=item * quads

=item * result_sets

=item * booleans

=back

=item C<< find_format_by_uri($uri, \%features) >>

Searches for a format by format URI.

=item C<< find_format_by_media_type($mt, \%features) >>

Searches for a format by media (MIME) type.

=item C<< find_format_by_media_type($name, \%features) >>

Searches for a format by name.

=item C<< find_format_by_capabilities(\%features) >>

Searches for a format by language features alone.

=item C<< known_media_types >>

Returns a list of all known media types, suitable for an HTTP Accept header.

=item C<< known_media_types_with_parsers >>

Narrows down the media type list to only those that can be parsed.

=item C<< known_media_types_with_serializers >>

Narrows down the media type list to only those that can be serialized.

=back
