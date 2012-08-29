package RDF::Trine::Serializer::RDFJSON;

use constant media_types => [qw( application/x-rdf+json )];
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
use namespace::autoclean;

use JSON qw(to_json);

with qw(
	RDF::Trine::Serializer::API
);

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	print {$fh} to_json($iter->as_hashref);
}

sub _serialize_bindings {
	confess "cannot handle bindings";
}

sub model_to_file {
	my $self  = shift;
	my $model = shift;
	my $file  = $self->_ensure_fh(shift);
	my $base  = shift;
	my %opts  = @_ || ();
	print {$file} to_json($model->as_hashref, \%opts);
}

sub model_to_string {
	my $self  = shift;
	my $model = shift;
	my $base  = shift;
	my %opts  = @_ || ();
	to_json($model->as_hashref, \%opts);
}

1;

