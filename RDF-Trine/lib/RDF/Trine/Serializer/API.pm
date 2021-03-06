package RDF::Trine::Serializer::API;

use Moose::Role;
use IO::Detect qw(is_filehandle);

# This appears to be a helper module rather than an API component.
# Parsers and serializers may wish to compose with it if they need
# it, but so far no serializers seem to need it, so there doesn't
# seem to be a reason to have it here.
#with qw(
#	RDF::Trine::Iterator::API::Converter
#);

requires qw(
	media_types
);

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

sub iterator_to_file
{
	my ($self, $iter, $fh, $base) = @_;
	
	if ($self->DOES('RDF::Trine::Serializer::API::Bindings')
	and not $self->DOES('RDF::Trine::Serializer::API::Graph'))
	{
		return $self->bindings_iterator_to_file( $iter => $fh, $base );
	}
	elsif ($self->DOES('RDF::Trine::Serializer::API::Graph')
	and not $self->DOES('RDF::Trine::Serializer::API::Bindings'))
	{
		return $self->graph_iterator_to_file( $iter => $fh, $base );
	}
	elsif ($iter->is_bindings or $iter->is_boolean)
	{
		return $self->bindings_iterator_to_file( $iter => $fh, $base );
	}
	else
	{
		return $self->graph_iterator_to_file( $iter => $fh, $base );
	}
}

sub iterator_to_string
{
	my ($self, $iter, $base) = @_;
	
	if ($self->DOES('RDF::Trine::Serializer::API::Bindings')
	and not $self->DOES('RDF::Trine::Serializer::API::Graph'))
	{
		return $self->bindings_iterator_to_string( $iter, $base );
	}
	elsif ($self->DOES('RDF::Trine::Serializer::API::Graph')
	and not $self->DOES('RDF::Trine::Serializer::API::Bindings'))
	{
		return $self->graph_iterator_to_string( $iter, $base );
	}
	elsif ($iter->is_bindings or $iter->is_boolean)
	{
		return $self->bindings_iterator_to_string( $iter, $base );
	}
	else
	{
		return $self->graph_iterator_to_string( $iter, $base );
	}
}

# back-compat
sub serialize_iterator_to_file
{
	my ($self, $fh, $iter) = @_;
	shift->iterator_to_file($iter, $fh);
}

# back-compat
sub serialize_iterator_to_string
{
	my ($self, $iter) = @_;
	shift->iterator_to_string($iter);
}

1;

__END__

=head1 NAME

RDF::Trine::Serializer::API - Interface Role for Serializers

=head1 TODO

Split documentation!

=head1 DESCRIPTION

=head2 Required

Every Serializer needs to implement:

=over 4

=item C<< media_types >>

A list of supported media types, used for linking serializers to formats

=item C<< _serialize_bindings($iter, $fh, $base) >>

Takes binding iterator $iter and serializes it to a filehandle $fh, optionally using the base URI $base.

=item C<< _serialize_graph($iter, $fh, $base) >>

Takes graph iterator $iter and serializes it to filehandle $fh, optionally using the base URI $base.

=back

=head2 Methods

This role provides the following methods.

Note that methods which accept a file handle also accept a file name;
and that base URIs are optional and generally ignored. (Most serializers
just output absolute URIs everywhere. Base URIs exist in the API just in
case a particular serializer needs them.)

=over 4

=item C<< model_to_file($model => $fh, $base) >>

=item C<< model_to_string($model, $base) >>

=item C<< graph_iterator_to_file($iter => $fh, $base) >>

=item C<< graph_iterator_to_string($iter, $base) >>

=item C<< bindings_iterator_to_file($iter => $fh, $base) >>

=item C<< bindings_iterator_to_string($iter, $base) >>

=item C<< iterator_to_file($iter => $fh, $base) >>

Automatically detects whether $iter is a graph or bindings iterator.

=item C<< iterator_to_string($iter, $base) >>

Automatically detects whether $iter is a graph or bindings iterator.

=back

The following methods are also provided for backwards compatibility.
Note that the order of arguments is reversed from the above methods.

=over 4

=item C<< serialize_model_to_file($fh, $model) >>

=item C<< serialize_model_to_string($model) >>

=item C<< serialize_iterator_to_file($fh, $iter) >>

=item C<< serialize_iterator_to_string($iter) >>

=back

=head1 AUTHOR

Konstantin Baierer C<< kba@cpan.org >>

Toby Inkster C<< tobyink@cpan.org >>

=cut
