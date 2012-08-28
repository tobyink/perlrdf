=head1 NAME

RDF::Trine::Store::Redland - Redland-backed RDF store for RDF::Trine

=head1 VERSION

This document describes RDF::Trine::Store::Redland version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Store::Redland;

=head1 DESCRIPTION

RDF::Trine::Store::Redland provides an RDF::Trine::Store interface to the
Redland RDF store.


=cut

package RDF::Trine::Store::Redland;

use strict;
use warnings;
use Moose;
with (
	'RDF::Trine::Store::API::TripleStore',
	'RDF::Trine::Store::API::Readable',
	'RDF::Trine::Store::API::Writeable',
	'RDF::Trine::Store::API::StableBlankNodes',
);

no warnings 'redefine';
use Encode;
use Data::Dumper;
use RDF::Redland 1.00;
use Scalar::Util qw(refaddr reftype blessed);

use RDF::Trine::Error;

######################################################################

our $NIL_TAG;
our $VERSION;
BEGIN {
	$VERSION	= "1.000";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	$NIL_TAG	= 'tag:gwilliams@cpan.org,2010-01-01:RT:NIL';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $store ) >>

Returns a new storage object using the supplied RDF::Redland::Model object.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Redland> for this backend.

The following keys may also be used:

=over

=item C<store_name>

The name of the storage factory (currently C<hashes>, C<mysql>,
C<memory>, C<file>, C<postgresql>, C<sqlite>, C<tstore>, C<uri> or
C<virtuoso>).

=item C<name>

The name of the storage.

=item C<options>

Any other options to be passed to L<RDF::Redland::Storage> as a hashref.

=back

=item C<new_with_object ( $redland_model )>

Initialize the store with a L<RDF::Redland::Model> object.


=cut

sub new {
	my $class	= shift;
	my $model	= shift;
	my $self	= bless({
		model	=> $model,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	my ($store_name, $name, $opts)	= split(/;/, $config, 3);
	my $store	= RDF::Redland::Storage->new( $store_name, $name, $opts );
	my $model	= RDF::Redland::Model->new( $store, '' );
	return $class->new( $model );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	my $store	= RDF::Redland::Storage->new(
						     $config->{store_name},
						     $config->{name},
						     $config->{options}
						    );
	my $model	= RDF::Redland::Model->new( $store, '' );
	return $class->new( $model );
}

sub _new_with_object {
	my $class	= shift;
	my $obj		= shift;
	return unless (blessed($obj) and $obj->isa('RDF::Redland::Model'));
	return $class->new( $obj );
}

sub _config_meta {
	return {
		required_keys	=> [qw(store_name name options)],
		fields			=> {
			store_name	=> { description => 'Redland Storage Type', type => 'string' },
			name		=> { description => 'Storage Name', type => 'string' },
			options		=> { description => 'Options String', type => 'string' },
		},
	}
}

=item C<< temporary_store >>

Returns a temporary (empty) triple store.

=cut

sub temporary_store {
	my $class	= shift;
	return $class->_new_with_string( "hashes;test;new='yes',hash-type='memory',contexts='yes'" );
}

=item C<< get_triples ( $subject, $predicate, $object ) >>

Returns an iterator of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_triples {
	my $self	= shift;
	my @nodes	= @_[0..2];
	
	my @rnodes;
	foreach my $pos (0 .. 2) {
		my $n	= $nodes[ $pos ];
		if (blessed($n) and not($n->is_variable)) {
			push(@rnodes, _cast_to_redland($n));
		} else {
			push(@rnodes, undef);
		}
	}
	
	my $iter	= $self->_get_statements_triple( @rnodes );
	return $iter;
}

sub _get_statements_triple {
	my $self	= shift;
	my @rnodes	= @_;
# 	warn '_get_statements_triple: ' . Dumper(\@rnodes);

	my $st		= RDF::Redland::Statement->new( @rnodes[0..2] );
	my $iter	= $self->_model->find_statements( $st );
	my %seen;
	my $sub		= sub {
		while (1) {
			return undef unless $iter;
			return undef if $iter->end;
			my $st	= $iter->current;
			if ($seen{ $st->as_string }++) {
				$iter->next;
				next;
			}
			my @nodes	= map { _cast_to_local($st->$_()) } qw(subject predicate object);
			$iter->next;
			return RDF::Trine::Statement->new( @nodes );
		}
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	my $model	= $self->_model;
	my @nodes	= $st->nodes;
	my @rnodes	= map { _cast_to_redland($_) } @nodes;
	my $rst		= RDF::Redland::Statement->new( @rnodes[0..2] );
	unless ($model->contains_statement($rst)) {
		$model->add_statement( $rst, $rnodes[3] );
	}
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	my $model	= $self->_model;
	my @nodes	= $st->nodes;
	my @rnodes	= map { _cast_to_redland($_) } @nodes;
	my $rst		= RDF::Redland::Statement->new( @rnodes[0..2] );
	$self->_model->remove_statement( $rst );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $context	= shift;
	my $iter	= $self->get_statements( $subj, $pred, $obj, $context );
	while (my $st = $iter->next) {
		$self->remove_statement( $st );
	}
}

=item C<< count_triples ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and object. Any of the arguments may be undef to match any value.

=cut

sub count_triples {
	my $self	= shift;
	my @nodes	= @_;
# 	warn "restricting count_statements to triple semantics";
	my @rnodes	= map { _cast_to_redland($_) } @nodes[0..2];
	my $st		= RDF::Redland::Statement->new( @rnodes );
	my $iter	= $self->_model->find_statements( $st );
	my $count	= 0;
	my %seen;
	while ($iter and my $st = $iter->current) {
		unless ($seen{ $st->as_string }++) {
			$count++;
		}
		$iter->next;
	}
	return $count;
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	return;
}

sub _model {
	my $self	= shift;
	return $self->{model};
}

sub _cast_to_redland ($) {
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('RDF::Trine::Statement')) {
		my @nodes	= map { _cast_to_redland( $_ ) } $node->nodes;
		return RDF::Redland::Statement->new( @nodes );
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Redland::Node->new_from_uri( $node->uri_value );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Redland::Node->new_from_blank_identifier( $node->blank_identifier );
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $lang	= $node->literal_value_language;
		my $dt		= $node->literal_datatype;
		my $value	= $node->literal_value;
		return RDF::Redland::Node->new_literal( "$value", $dt, $lang );
	} elsif ($node->isa('RDF::Trine::Node::Nil')) {
		return RDF::Redland::Node->new_from_uri( $NIL_TAG );
	} else {
		return undef;
	}
}

sub _cast_to_local ($) {
	my $node	= shift;
	return undef unless (blessed($node));
	my $type	= $node->type;
	if ($type == $RDF::Redland::Node::Type_Resource) {
		my $uri	= $node->uri->as_string;
		if ($uri eq $NIL_TAG) {
			return RDF::Trine::Node::Nil->new();
		} else {
			return RDF::Trine::Node::Resource->new( $uri );
		}
	} elsif ($type == $RDF::Redland::Node::Type_Blank) {
		return RDF::Trine::Node::Blank->new( $node->blank_identifier );
	} elsif ($type == $RDF::Redland::Node::Type_Literal) {
		my $lang	= $node->literal_value_language;
		my $dturi	= $node->literal_datatype;
		my $dt		= ($dturi)
					? $dturi->as_string
					: undef;
		my $value	= $node->literal_value;
		if ($RDF::Redland::VERSION < 1.0014) {
			$value	= decode('utf8', $value);
		}
		return RDF::Trine::Node::Literal->new( $value, $lang, $dt );
	} else {
		return undef;
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
