package RDF::Trine::Serializer::NQuads;

use constant media_types => [qw( text/x-nquads )];
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
with qw(
	RDF::Trine::Serializer::API::Graph
);

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	while (my $st = $iter->next) {
		print {$fh} $self->statement_as_string($st);
	}
}

sub serialize_node      { $_[1]->as_ntriples }
sub statement_as_string {
	my $st = $_[1];
	return $st->as_ntriples if $st->type eq 'TRIPLE';
	return $st->as_ntriples if $st->graph->is_nil;
	return $st->as_ntriples if $st->graph->is_resource && $st->graph->uri eq RDF::Trine::NIL_GRAPH;
	return $st->as_nquads;
}

sub _serialize_bounded_description {
	my ($self, $model, $node, $seen) = @_;
	$seen ||= {};
	return '' if $seen->{ $node->sse }++;
	
	my $iter   = $model->get_statements( $node, undef, undef );
	my $string = '';
	while (my $st = $iter->next) {
		$string .= $self->statement_as_string($st);
		if ($st->object->is_blank) {
			$string .= $self->_serialize_bounded_description($model, $st->object, $seen);
		}
	}
	return $string;
}

__PACKAGE__->meta->make_immutable;
1;

