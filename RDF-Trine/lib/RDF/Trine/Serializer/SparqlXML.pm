package RDF::Trine::Serializer::SparqlXML;

use constant media_types => [qw( application/sparql-results+xml )];
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
with qw(
	RDF::Trine::Serializer::API::Bindings
);

sub _serialize_bindings {
	my ($self, $iter, $fh) = @_;

	my $max_result_size  = shift || 0;
	my $width            = $iter->bindings_count;
	
	my @variables;
	for my $i (1 .. $width) {
		my $name = $iter->binding_name($i - 1);
		push @variables, $name if $name;
	}
	
	no strict 'refs';
	print {$fh} <<"END";
<?xml version="1.0" encoding="utf-8"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
END
	
	my $t = join("\n", map { qq(\t<variable name="$_"/>) } @variables);
	
	if ($t) {
		print {$fh} "${t}\n";
	}
	
	print {$fh} <<"END";
</head>
<results>
END
	
	my $count = 0;
	while (my $row = $iter->next) {
		my @row;
		print {$fh} "\t\t<result>\n";
		for (my $i = 0; $i < $width; $i++) {
			my $name   = $iter->binding_name($i);
			my $value  = $row->{ $name };
			print {$fh} "\t\t\t" . $self->format_node_xml($value, $name) . "\n";
		}
		print {$fh} "\t\t</result>\n";
		
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	
	print {$fh} "</results>\n";
	print {$fh} "</sparql>\n";
}

sub format_node_xml {
	my ($self, $node, $name) = @_;
	my $node_label;
	
	if (defined $node) {
		$node_label = $node->value;
		$node_label =~ s/&/&amp;/g;
		$node_label =~ s/</&lt;/g;
		$node_label =~ s/"/&quot;/g;
	}
	else {
		return '';
	}
	
	if ($node->is_resource) {
		$node_label = qq(<uri>${node_label}</uri>);
	}
	elsif ($node->isa('RDF::Trine::Node::Literal')) {
		if ($node->has_language) {
			my $lang = $node->language;
			$node_label = qq(<literal xml:lang="${lang}">${node_label}</literal>);
		}
		elsif ($node->has_datatype) {
			my $dt = $node->datatype;
			$node_label = qq(<literal datatype="${dt}">${node_label}</literal>);
		}
		else {
			$node_label = qq(<literal>${node_label}</literal>);
		}
	}
	elsif ($node->isa('RDF::Trine::Node::Blank')) {
		$node_label = qq(<bnode>${node_label}</bnode>);
	}
	else {
		$node_label = "<unbound/>";
	}
	
	return qq(<binding name="${name}">${node_label}</binding>);
}


__PACKAGE__->meta->make_immutable;
1;

