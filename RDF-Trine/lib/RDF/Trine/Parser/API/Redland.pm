package RDF::Trine::Parser::API::Redland;
use Moose::Role;
use Scalar::Util qw(blessed reftype);
use IO::String;

requires (
    '_build_redland_parser',
);

has redland_parser => (
    is => 'rw',
    isa => 'RDF::Redland::Parser',
    lazy => 1,
    builder => '_build_redland_parser',
);

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler = shift;

    my $fh = (ref $string) ? $string : IO::String->new( $string );
	$self->_parse_graph( $fh, $handler, $base );
}

sub _parse_graph {
	my $self	= shift;
	my $fh	    = shift;
	my $handler = shift;
	my $base	= shift;

	my $string = do { local $/; <$fh> };
	
	my $null_base	= 'urn:uuid:1d1e755d-c622-4610-bae8-40261157687b';
	if ($base and blessed($base) and $base->isa('URI')) {
		$base	= $base->as_string;
	}
	$base		= RDF::Redland::URI->new(defined $base ? $base : $null_base);
	my $stream	= eval {
		$self->redland_parser->parse_string_as_stream($string, $base)
	};
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => $@;
	}
	
	while ($stream and !$stream->end) {
		#my $context = $stream->context;
		#warn $context;
		my $stmt = RDF::Trine::Statement::API->from_redland($stream->current);
		if ($self->canonicalize) {
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
	
    # XXX
    # Not sure if this good as such, no other parsers use this
	if (my $map = $self->namespaces ) {
		my %seen	= $self->redland_parser->namespaces_seen;
		while (my ($ns, $uri) = each(%seen)) {
			$map->add_mapping( $ns => $uri->as_string );
		}
	}
	return;
}

sub _parse_bindings {
    my $self = shift;
    return $self->_graph_to_bindings( @_ );
}

1;
