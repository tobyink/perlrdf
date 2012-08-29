package RDF::Trine::Serializer::API;

use Moose::Role;
use IO::Detect qw(is_filehandle);

with (
    'RDF::Trine::Iterator::API::Converter'
);

requires (
    '_serialize_graph',
    '_serialize_bindings',
    'media_types',
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

sub model_to_file
{
	my ($self, $model, $fh, $base) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_graph( $model->as_stream => $fh, $base );
}

sub model_to_string
{
	my ($self, $model, $base) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_graph( $model->as_stream => $fh, $base );
	close $fh;
	return $string;
}

sub bindings_iterator_to_file
{
	my ($self, $iter, $fh, $base) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_bindings( $iter => $fh, $base );
}

sub bindings_iterator_to_string
{
	my ($self, $iter, $base) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_bindings( $iter => $fh, $base );
	close $fh;
	return $string;
}

sub graph_iterator_to_file
{
	my ($self, $iter, $fh, $base) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_graph( $iter => $fh, $base );
}

sub graph_iterator_to_string
{
	my ($self, $iter, $base) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_graph( $iter => $fh, $base );
	close $fh;
	return $string;
}

sub iterator_to_file
{
	my ($self, $iter, $fh, $base) = @_;
	$iter->is_graph
		? $self->graph_iterator_to_file( $iter => $fh, $base )
		: $self->bindings_iterator_to_file( $iter => $fh, $base )
}

sub iterator_to_string
{
	my ($self, $iter, $base) = @_;
	$iter->is_graph
		? $self->graph_iterator_to_string( $iter, $base )
		: $self->bindings_iterator_to_string( $iter, $base )
}

# back-compat
sub serialize_model_to_file
{
	my ($self, $fh, $model) = @_;
	shift->model_to_file($model, $fh);
}

# back-compat
sub serialize_model_to_string
{
	my ($self, $model) = @_;
	shift->model_to_string($model);
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

=head1 DESCRIPTION

=head2 Required

Every Serializer needs to implement:

=over 4

=item C<< media_types >>

A constant arrayref of supported media types, used for linking serializers to formats

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
