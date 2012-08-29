package RDF::Trine::Parser::API;
use Moose::Role;

with (
    'RDF::Trine::Iterator::API::Converter'
);

requires (
    '_parse_graph',
    '_parse_bindings',
    'media_types',
);

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
