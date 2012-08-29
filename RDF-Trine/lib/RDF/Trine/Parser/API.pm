package RDF::Trine::Parser::API;
use Moose::Role;
use TryCatch;
use List::MoreUtils qw(uniq);
use IO::Detect qw(is_filehandle);
use IO::String;

with (
    'RDF::Trine::Iterator::API::Converter'
);

requires (
    '_parse_graph',
    '_parse_bindings',
    'media_types',
);

has [qw(canonicalize )] => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has bnode_id => (
    is => 'ro',
    isa => 'Num',
    traits => ['Counter'],
    lazy => 1,
    default => 0,
    handles => {
        inc_bnode_id => 'inc',
    },
);

has bnode_prefix => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_build_bnode_prefix',
);

sub _build_bnode_prefix {
    my $self = shift;
    return $self->new_bnode_prefix;
}

has bindings => (
    is => 'ro',
    isa => 'HashRef[Str]',
    lazy => 1,
    builder => '_build_bindings',
    traits => ['Hash'],
    handles => {
        set_binding => 'set',
        get_binding => 'get',
        has_binding => 'exists',
    }
);

sub _build_bindings { {} }



sub _ensure_fh
{
	my ($self, $fh) = @_;
	unless (is_filehandle $fh) {
		my $filename = $fh;
		undef $fh;
		open $fh, '>', $filename;
	}
	return $fh;
}


=item C<< parse_url_into_model ( $url, $model [, %args] ) >>

Retrieves the content from C<< $url >> and attempts to parse the resulting RDF
into C<< $model >> using a parser chosen by the associated content media type.

If C<< %args >> contains a C<< 'content_cb' >> key with a CODE reference value,
that callback function will be called after a successful response as:

 $content_cb->( $url, $content, $http_response_object )

=cut

sub parse_url_into_model {
	my $class	= shift;
	my $url		= shift;
	my $model	= shift;
	my %args	= @_;
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Trine/$RDF::Trine::VERSION" );
	
	# prefer RDF/XML or Turtle, then anything else that we've got a parser for.
    my $accept = join( ',',
        map { /(turtle|rdf[+]xml)/ ? "$_;q=1.0" : "$_;q=0.9" }
          RDF::Trine::FormatRegistry->instance->known_media_types );
	$ua->default_headers->push_header( 'Accept' => $accept );
	
	my $resp	= $ua->get( $url );
	if ($url =~ /^file:/) {
		my $type	= guess_media_type($url);
		$resp->header('Content-Type', $type);
	}
	
	unless ($resp->is_success) {
		throw RDF::Trine::Error::ParserError -text => $resp->status_line;
	}
	
	my $content	= $resp->content;
	if (my $cb = $args{content_cb}) {
		$cb->( $url, $content, $resp );
	}
	
	my $type	= $resp->header('content-type');
	$type		=~ s/^([^\s;]+).*/$1/;
	my $format = RDF::Trine::FormatRegistry->instance->find_format_by_media_type( $type );
	unless ($format && $format->parsers->[0]) {
		throw RDF::Trine::Error::ParserError -text => "No parser found for content type $type";
    }
    # TODO this just chooeses the first, not the best (whatever that may mean)
    my $parser = $format->parsers->[0];
    my $data	= $content;
#       TODO encoding issues can be format- and parser-specific
#       This will have to be done when the Capabilities API is stable
#       if (my $e = $encodings{ $pclass }) {
#           $data	= decode( $e, $content );
#		}

    # pass %args in here too so the constructor can take its pick
    my $ok	= 0;
    try {
        $parser->parse_into_model( $url, $data, $model, %args );
        $ok	= 1;
    } catch (RDF::Trine::Error $e) {};
    return 1 if ($ok);
	
	### FALLBACK
	my %options;
	if (defined $args{canonicalize}) {
		$options{ canonicalize }	= $args{canonicalize};
	}
	if ($url =~ /[.](x?rdf|owl)$/ or $content =~ m/\x{FEFF}?<[?]xml /smo) {
		my $parser	= RDF::Trine::Parser::RDFXML->new(%options);
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]ttl$/ or $content =~ m/@(prefix|base)/smo) {
		my $parser	= RDF::Trine::Parser::Turtle->new(%options);
		my $data	= decode('utf8', $content);
		$parser->parse_into_model( $url, $data, $model, %args );
		return 1;
	} elsif ($url =~ /[.]trig$/) {
		my $parser	= RDF::Trine::Parser::Trig->new(%options);
		my $data	= decode('utf8', $content);
		$parser->parse_into_model( $url, $data, $model, %args );
		return 1;
	} elsif ($url =~ /[.]nt$/) {
		my $parser	= RDF::Trine::Parser::NTriples->new(%options);
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]nq$/) {
		my $parser	= RDF::Trine::Parser::NQuads->new(%options);
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]js(?:on)?$/) {
		my $parser	= RDF::Trine::Parser::RDFJSON->new(%options);
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]x?html?$/) {
		my $parser	= RDF::Trine::Parser::RDFa->new(%options);
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} else {
        my @types = uniq RDF::Trine::FormatRegistry->instance->known_media_types;
		foreach my $pclass (@types) {
			my $data	= $content;
#           TODO encoding issues can be format- and parser-specific
#           This will have to be done when the Capabilities API is stable
#			if (my $e = $encodings{ $pclass }) {
#				$data	= decode( $e, $content );
#			}
			my $parser	= $pclass->new(%options);
			my $ok		= 0;
			try {
				$parser->parse_into_model( $url, $data, $model, %args );
				$ok	= 1;
			} catch( RDF::Trine::Error::ParserError $e) {};
			return 1 if ($ok);
		}
	}
	throw RDF::Trine::Error::ParserError -text => "Failed to parse data from $url";
}

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
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};

    # ensure that _parse_graph/_parse_bindings gets an iterator
	my $fh = (ref $input) ? $input : IO::String->new($input);
	
	$model->begin_bulk_ops();
    # XXX this should distinguish between _parse_graph and _parse_bindings
	my $s	= $self->_parse_graph( $fh, $handler, $uri );
	$model->end_bulk_ops();
	return $s;
}

=item C<< parse_file_into_model ( $base_uri, $fh, $model [, context => $context] ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the 
given C<< $base_uri >>. For each RDF statement parsed, will call
C<< $model->add_statement( $statement ) >>.

=cut

sub parse_file_into_model {
	my $proto	= shift;
	my $self	= (blessed($proto) or $proto eq  __PACKAGE__)
			? $proto : $proto->new();
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $fh		= shift;
	my $model	= shift;
	my %args	= @_;
	my $context	= $args{'context'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	
	$model->begin_bulk_ops();
	my $s	= $self->parse_file( $uri, $fh, $handler );
	$model->end_bulk_ops();
	return $s;
}

=item C<< parse_file ( $base_uri, $fh, $handler ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the given
C<< $base_uri >>. If C<< $fh >> is a filename, this method can guess the
associated parse. For each RDF statement parses C<< $handler >> is called.

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;

	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		unless ($self->can('parse')) {
			my $pclass = $self->guess_parser_by_filename( $filename );
			$self = $pclass->new() if ($pclass and $pclass->can('new'));
		}
		open( $fh, '<:utf8', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}

	if ($self and $self->can('parse')) {
		my $content	= do { local($/) = undef; <$fh> };
		return $self->parse( $base, $content, $handler, @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "Cannot parse unknown serialization";
	}
}

=item C<< new_bnode_prefix () >>

Returns a new prefix to be used in the construction of blank node identifiers.
If either Data::UUID or UUID::Tiny are available, they are used to construct
a globally unique bnode prefix. Otherwise, an empty string is returned.

=cut

sub new_bnode_prefix {
	my $class	= shift;
	if (defined($Data::UUID::VERSION)) {
		my $ug		= new Data::UUID;
		my $uuid	= $ug->to_string( $ug->create() );
		$uuid		=~ s/-//g;
		return 'b' . $uuid;
	} elsif (defined($UUID::Tiny::VERSION) && ($] < 5.014000)) { # UUID::Tiny 1.03 isn't working nice with thread support in Perl 5.14. When this is fixed, this may be removed and dep added.
		no strict 'subs';
		my $uuid	= UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V1);
		$uuid		=~ s/-//g;
		return 'b' . $uuid;
	} else {
		return '';
	}
}


1;

__END__

=head1 NAME

RDF::Trine::Parser::API - Interface Role for Parsers

=head1 DESCRIPTION

Every Parser needs to implement

=over 4

=item media_types

A constant array of supported media types, used for linking parsers to formats

=item _parse_bindings( $fh, $handler, $base )

Takes filehandle $fh and parses from it to handler $handler using a tabular
bindings structure, optionally using base URI $base.

=item _parse_graph( $fh, $handler, $base )

Takes filehandle $fh and parses from it to handler $handler using a graph
structure, optionally using base URI $base.

=back

=cut
