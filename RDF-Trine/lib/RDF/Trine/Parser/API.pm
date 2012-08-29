package RDF::Trine::Parser::API;
use Moose::Role;

with (
    'RDF::Trine::Iterator::API::Converter'
);

requires (
    '_parse_graph',
    '_parse_bindings',
    'media_type',
);

1;

__END__

=head1 NAME

RDF::Trine::Parser::API - Interface Role for Parsers

=head1 DESCRIPTION

Every Parser needs to implement

=over 4

=item media_type

A constant array of supported media types, used for linking parsers to formats

=item _parse_bindings

Takes a filehandle and parses it into bindings iterator

=item _parse_graph

Takes a filehandle and parses it into a graph iterator

=back

=cut
