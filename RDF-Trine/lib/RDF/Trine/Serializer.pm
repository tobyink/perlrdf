package RDF::Trine::Serializer;

use strict;
use warnings;

use HTTP::Negotiate qw(choose);

use RDF::Trine::Serializer::NQuads;
use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::NTriples::Canonical;
use RDF::Trine::Serializer::RDFXML;
use RDF::Trine::Serializer::RDFJSON;
use RDF::Trine::Serializer::TSV;
use RDF::Trine::Serializer::Turtle;
use RDF::Trine::Types qw(TrineFormat);

sub media_types {
	RDF::Trine::FormatRegistry->instance->known_media_types_with_serializers
}

sub serializer_names {
	return
		map { $_->name }
		RDF::Trine::FormatRegistry->instance->filter_formats(
			sub { defined $_->serializers->[0] }
		);
}

sub new {
	my $class = shift;
	my $name  = shift;
	my $fmt   = TrineFormat->coerce($name);
	
	if ($fmt) {
		return $fmt->serializers->[0]->new(@_);
	}
	
	RDF::Trine::Exception->throw(
		message => "No serializer known matching $name",
	);
}

sub _negotiate {
	my ($class, $features, %options) = @_;
	my $headers = delete $options{'request_headers'};
	my $choice  = choose(
		RDF::Trine::FormatRegistry->instance->http_negotiate($features),
		$headers,
	);
	$class->new($choice, %options);
}

sub negotiate {
	my ($class, %options) = @_;
	$class->_negotiate(+{ triples => 1 }, %options);
}

sub negotiate_for_bindings {
	my ($class, %options) = @_;
	$class->_negotiate(+{ bindings => 1 }, %options);
}

sub negotiate_for_quads {
	my ($class, %options) = @_;
	$class->_negotiate(+{ quads => 1 }, %options);
}

{
	package RDF::Trine::Serializer::FileSink;
	use strict;
	use warnings;
	sub new {
		my $class = shift;
		bless \@_ => $class;
	}
	sub emit {
		my $self = shift;
		my $data = shift;
		print {$self->[0]} $data;
	}
}

{
	package RDF::Trine::Serializer::StringSink;
	use strict;
	use warnings;
	use Encode;
	sub new {
		my $class  = shift;
		my $string = decode_utf8("");
		bless \$string => $class;
	}
	sub emit {
		my $self = shift;
		my $data = shift;
		$$self  .= $data;
	}
	sub prepend {
		my $self = shift;
		my $data = shift;
		$$self   = $data . $$self;
	}
	sub string {
		${ +shift };
	}
}

1;

__END__

=head1 NAME

RDF::Trine::Serializer - serializer factory

=head1 DESCRIPTION

This class provides a number of convenience class methods for instantiating
serializer objects.

=head2 Methods

=over

=item C<< new($serializer_name, %options) >>

Instantiates a serializer by format name.

=item C<< new($media_type, %options) >>

Instantiates a serializer by media type.

=item C<< new($uri, %options) >>

Instantiates a serializer by format URI.

=item C<< negotiate ( request_headers => $request_headers, %options ) >>

Returns a two-element list containing an appropriate media type and
RDF::Trine::Serializer object as decided by L<HTTP::Negotiate>.  If
the C<< 'request_headers' >> key-value is supplied, the C<<
$request_headers >> is passed to C<< HTTP::Negotiate::choose >>. 

=begin TODO

The option C<< 'restrict' >>, set to a list of serializer names, can be
used to limit the serializers to choose from. Finally, an C<<'extends' >> 
option can be set to a hashref that contains MIME-types
as keys and a custom variant as value. This will enable the user to
use this negotiator to return a type that isn't supported by any
serializers. The subsequent code will have to find out how to return a
representation.

=end TODO

The rest of C<< %options >> is passed through to the serializer constructor.

This method only negotiates between formats which are capable of holding
triples, and for which a serializer is known.

=item C<< negotiate_for_quads ( request_headers => $request_headers, %options ) >>

As per C<negotiate> but only negotiates between formats that can hold quads.

=item C<< negotiate_for_bindings ( request_headers => $request_headers, %options ) >>

As per C<negotiate> but only negotiates between formats that can hold SPARQL
result sets.

=back

=cut
