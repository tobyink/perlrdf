package RDF::Trine::Serializer::TSV;

use constant media_types => [qw( text/tab-separated-values )];
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
use MooseX::Types::Moose qw(Bool);
with qw(
	RDF::Trine::Serializer::API::Bindings
);

has output_headers => (
	is      => 'ro',
	isa     => Bool,
	default => 1,
);

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	my $header;
	while (my $st = $iter->next) {
		$header ||= print {$fh} join("\t", map { substr($_, 0, 1) } $st->node_names), "\n"
			if $self->output_headers;
		print {$fh} $self->statement_as_string($st);
	}
}

sub _serialize_bindings {
	my ($self, $iter, $fh) = @_;
	my $header;
	while ($iter->next) {
		$header ||= print {$fh} join("\t", $iter->binding_names), "\n"
			if $self->output_headers;
		print {$fh} join("\t", map { $_->as_ntriples } $iter->binding_values), "\n";
	}
}

sub _serialize_bounded_description {
	my ($self, $model, $node, $seen) = @_;
	$seen ||= do {
		print join("\t", qw(s p o)), "\n" if $self->output_headers;
		+{}
	};
	return '' if ($seen->{ $node->sse }++);
	my $iter   = $model->get_statements($node, undef, undef);
	my $string = '';
	while (my $st = $iter->next) {
		my @nodes = $st->nodes;
		$string .= $self->statement_as_string( $st );
		if ($nodes[2]->isa('RDF::Trine::Node::Blank')) {
			$string .= $self->_serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

sub statement_as_string {
	my ($self, $st) = @_;
	return join("\t", map { $_->as_ntriples } $st->nodes) . "\n";
}

__PACKAGE__->meta->make_immutable;
1;


__END__

=item C<< statement_as_string ( $st ) >>

Returns a string with the nodes of the given RDF::Trine::Statement serialized in N-Triples format, separated by tab characters.

=cut

