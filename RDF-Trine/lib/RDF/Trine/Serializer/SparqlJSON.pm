package RDF::Trine::Serializer::SparqlJSON;

use constant media_types => qw( application/sparql-results+json );
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use JSON qw(to_json);

use Moose;
with qw(
	RDF::Trine::Serializer::API::Bindings
);

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	$self->_serialize_bindings($iter->as_bindings => $fh);
}

sub _serialize_bindings {
	my ($self, $iter, $fh) = @_;
	
	my $max_result_size = shift || 0;
	my $width           = $iter->bindings_count;
	
	my @variables;
	for my $i (1 .. $width) {
		my $name = $iter->binding_name($i - 1);
		push @variables, $name if $name;
	}
	
	my $count  = 0;
	my @sorted = $iter->sorted_by;
	my $order  = scalar(@sorted) ? JSON::true : JSON::false;
	my $dist   = $iter->_args->{distinct} ? JSON::true : JSON::false;
	
	my $data = {
		head     => { vars => \@variables },
		results  => { ordered => $order, distinct => $dist, bindings => [] },
	};
	my @bindings;
	while (my $row = $iter->next) {
		my %row = map { $self->format_node_json($row->{$_}, $_) } (keys %$row);
		push @{ $data->{results}{bindings} }, \%row;
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	
	print $fh to_json($data);
}

sub format_node_json {
	my ($self, $node, $name) = @_;
	my $node_label;
	
	if(!defined $node) {
		return;
	}
	elsif ($node->isa('RDF::Trine::Node::Resource')) {
		$node_label = $node->uri_value;
		return $name => { type => 'uri', value => $node_label };
	}
	elsif ($node->isa('RDF::Trine::Node::Literal')) {
		$node_label = $node->literal_value;
		return $name => { type => 'literal', value => $node_label };
	}
	elsif ($node->isa('RDF::Trine::Node::Blank')) {
		$node_label = $node->blank_identifier;
		return $name => { type => 'bnode', value => $node_label };
	}
	else {
		return;
	}
}


__PACKAGE__->meta->make_immutable;
1;
