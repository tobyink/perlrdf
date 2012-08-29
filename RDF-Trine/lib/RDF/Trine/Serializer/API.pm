package RDF::Trine::Serializer::API;
use Moose::Role;

with (
    'RDF::Trine::Iterator::API::Converter'
);

requires (
    '_serialize_graph',
    '_serialize_bindings',
    'media_types',
);

1;

__END__

=head1 NAME

RDF::Trine::Serializer::API - Interface Role for Serializers

=head1 DESCRIPTION

Every Serializer needs to implement

=over 4

=item media_type

A constant array of supported media types, used for linking serializers to formats

=item _serialize_bindings

Takes a binding iterator and serializes it to a filehandle

=item _serialize_graph

Takes a graph iterator and serializes it to a filehandle

=back

=cut
