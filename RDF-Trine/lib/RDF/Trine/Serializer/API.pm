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

=item media_types

A constant array of supported media types, used for linking serializers to formats

=item _serialize_bindings( $iter, $fh, $base )

Takes binding iterator $iter and serializes it to a filehandle $fh, optionally using the base URI $base.

=item _serialize_graph( $iter, $fh, $base )

Takes graph iterator $iter and serializes it to filehandle $fh, optionally using the base URI $base.

=back

=cut
