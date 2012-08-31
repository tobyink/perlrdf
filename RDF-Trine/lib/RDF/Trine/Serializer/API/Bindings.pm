package RDF::Trine::Serializer::API::Bindings;

use Moose::Role
with qw(
	RDF::Trine::Serializer::API
	RDF::Trine::Serializer::API::Graph
);

requires qw(
	_serialize_bindings
);

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	$self->_serialize_bindings($iter->as_bindings => $fh);
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

