package RDF::Trine::Serializer::API;

use Moose::Role;
use IO::Detect qw(is_filehandle);

requires qw(
	_serialize_graph
	_serialize_bindings
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

sub model_to_file
{
	my ($self, $model, $fh) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_graph( $model->as_stream => $fh );
}

sub model_to_string
{
	my ($self, $model) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_graph( $model->as_stream => $fh );
	close $fh;
	return $string;
}

sub bindings_iterator_to_file
{
	my ($self, $iter, $fh) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_bindings( $iter => $fh );
}

sub bindings_iterator_to_string
{
	my ($self, $iter) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_bindings( $iter => $fh );
	close $fh;
	return $string;
}

sub graph_iterator_to_file
{
	my ($self, $iter, $fh) = @_;
	$fh = $self->_ensure_fh($fh);
	$self->_serialize_graph( $iter => $fh );
}

sub graph_iterator_to_string
{
	my ($self, $iter) = @_;
	my $string;
	open my $fh, '>', \$string;
	$self->_serialize_graph( $iter => $fh );
	close $fh;
	return $string;
}

sub iterator_to_file
{
	my ($self, $iter, $fh) = @_;
	$iter->is_graph
		? $self->graph_iterator_to_file( $iter => $fh )
		: $self->bindings_iterator_to_file( $iter => $fh )
}

sub iterator_to_string
{
	my ($self, $iter) = @_;
	$iter->is_graph
		? $self->graph_iterator_to_string( $iter )
		: $self->bindings_iterator_to_string( $iter )
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

=item C<< _serialize_bindings($iter, $fh) >>

Takes a binding iterator and serializes it to a filehandle

=item C<< _serialize_graph($iter, $fh) >>

Takes a graph iterator and serializes it to a filehandle

=back

=head2 Methods

This role provides the following methods:

=over 4

=item C<< model_to_file($model => $fh) >>

Note that methods which accept a file handle, also accept a file name.

=item C<< model_to_string($model) >>

=item C<< graph_iterator_to_file($iter => $fh) >>

=item C<< graph_iterator_to_string($iter) >>

=item C<< bindings_iterator_to_file($iter => $fh) >>

=item C<< bindings_iterator_to_string($iter) >>

=item C<< iterator_to_file($iter => $fh) >>

Automatically detects whether $iter is a graph or bindings iterator.

=item C<< iterator_to_string($iter) >>

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

=cut
