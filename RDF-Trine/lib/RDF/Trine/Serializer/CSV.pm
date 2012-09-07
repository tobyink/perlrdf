package RDF::Trine::Serializer::CSV;

use constant media_types => qw( text/csv );
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Class::Load;
use IO::Handle;

use Moose;
use MooseX::Types::Moose qw(Str Bool Object);
with qw(
	RDF::Trine::Serializer::API::Bindings
);

has output_headers => (
	is         => 'ro',
	isa        => Bool,
	default    => 1,
);

has quote => (
	is         => 'ro',
	isa        => Bool,
	default    => 0,
);

has sep_char => (
	is         => 'ro',
	isa        => Str,
	default    => q(,),
);

has eol => (
	is         => 'ro',
	isa        => Str,
	default    => qq(\n),
);

has csv => (
	is         => 'ro',
	isa        => Object,
	lazy_build => 1,
);

my $CSV_CLASS;
sub _build_csv {
	my $self = shift;
	$CSV_CLASS ||= Class::Load::load_first_existing_class(
		'Text::CSV_XS'  => +{ },
		'Text::CSV'     => +{ },
	);
	$CSV_CLASS->new({ binary => 1, sep_char => $self->sep_char, eol => $self->eol })
		or confess $CSV_CLASS->error_diag;
};

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	my $csv = $self->csv;
	my $q   = $self->quote;
	my $header;
	while (my $st = $iter->next) {
		$header ||= $csv->print($fh, [map { substr($_, 0, 1) } $st->node_names])
			if $self->output_headers;
		$csv->print($fh, [
			map { $q ? $_->as_string : $_->value }
			$st->nodes
		]);
	}
}

sub _serialize_bindings {
	my ($self, $iter, $fh) = @_;
	my $csv = $self->csv;
	my $q   = $self->quote;
	my @F;
	my $header;
	while (my $row = $iter->next) {
		@F = reverse sort keys %$row unless @F;
		$header ||= $csv->print($fh, \@F)
			if $self->output_headers;
		$csv->print($fh, [
			map {
				defined($row->{$_})
					? ( $q ? $row->{$_}->as_string : $row->{$_}->value )
					: q[]
			} @F
		]);
	}
}

__PACKAGE__->meta->make_immutable;
1;


__END__

=item C<< statement_as_string ( $st ) >>

Returns a string with the nodes of the given RDF::Trine::Statement serialized in N-Triples format, separated by tab characters.

=cut

