package RDF::Trine::Serializer::NTriples;

use constant media_types => qw( text/plain );
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

sub model_to_file
{
	my ($self, $model, $fh) = @_;
	$fh = $self->_ensure_fh($fh);
	
	my $st     = RDF::Trine::Statement::Triple->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat    = RDF::Trine::Pattern->new( $st );
	my $stream = $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	  = $stream->as_statements( qw(s p o) );
	
	while (my $st = $iter->next) {
		print {$fh} $st->as_ntriples;
	}
}

sub serialize_node      { $_[1]->as_ntriples }
sub statement_as_string { $_[1]->as_ntriples }

sub _serialize_bounded_description {
	my ($self, $model, $node, $seen) = @_;
	$seen ||= {};
	return '' if $seen->{ $node->sse }++;
	
	my $iter   = $model->get_statements( $node, undef, undef );
	my $string = '';
	while (my $st = $iter->next) {
		$string .= $st->as_ntriples;
		if ($st->object->is_blank) {
			$string .= $self->_serialize_bounded_description($model, $st->object, $seen);
		}
	}
	return $string;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

RDF::Trine::Serializer::NTriples - write data in N-Triples format

=head DESCRIPTION

This serializer implements L<RDF::Trine::Serializer::API>.

=head2 Methods

This module provides the following additional methods.

=over

=item C<< serialize_node($node) >>

=item C<< statement_as_string($st) >>

=back


