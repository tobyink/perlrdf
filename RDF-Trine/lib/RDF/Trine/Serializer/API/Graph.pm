package RDF::Trine::Serializer::API::Graph;

use Moose::Role
with qw(
	RDF::Trine::Serializer::API
);

requires qw(
	_serialize_graph
);

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

