# RDF::Trine::Store
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Store - RDF triplestore base class

=head1 VERSION

This document describes RDF::Trine::Store version 1.000

=head1 DESCRIPTION

RDF::Trine::Store provides a base class and common API for implementations of
triple/quadstores for use with the RDF::Trine framework. In general, it should
be used only be people implementing new stores. For interacting with stores
(e.g. to read, insert, and delete triples) the RDF::Trine::Model interface
should be used (using the model as an intermediary between the client/user and
the underlying store).

To be used by the RDF::Trine framework, store implementations must implement a
set of required functionality:

=over 4

=item * C<< new >>

=item * C<< get_statements >>

=item * C<< get_contexts >>

=item * C<< add_statement >>

=item * C<< remove_statement >>

=item * C<< count_statements >>

=item * C<< supports >>

=back

Implementations may also provide the following methods if a native
implementation would be more efficient than the default provided by
RDF::Trine::Store:

=over 4

=item * C<< get_pattern >>

=item * C<< get_sparql >>

=item * C<< remove_statements >>

=item * C<< size >>

=item * C<< nuke >>

=item * C<< _begin_bulk_ops >>

=item * C<< _end_bulk_ops >>

=back

=cut

package RDF::Trine::Store;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use Module::Load::Conditional qw[can_load];

# use RDF::Trine::Store::Memory;
# use RDF::Trine::Store::Hexastore;
# use RDF::Trine::Store::SPARQL;

######################################################################

our ($VERSION, $HAVE_REDLAND, %STORE_CLASSES);
BEGIN {
	$VERSION	= '1.000';
	if ($RDF::Redland::VERSION) {
		$HAVE_REDLAND	= 1;
	}
# 	can_load( modules => {
# 		'RDF::Trine::Store::DBI'	=> undef,
# 	} );
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $data ) >>

Returns a new RDF::Trine::Store object based on the supplied data value.
This constructor delegates to one of the following methods depending on the
value of C<< $data >>:

* C<< new_with_string >> if C<< $data >> is not a reference

* C<< new_with_config >> if C<< $data >> is a HASH reference

* C<< new_with_object >> if C<< $data >> is a blessed object

=cut

sub new {
	my $class	= shift;
	my $data	= shift;
	if (blessed($data)) {
		return $class->new_with_object($data);
	} elsif (ref($data)) {
		return $class->new_with_config($data);
	} else {
		return $class->new_with_string($data);
	}
}

=item C<< new_with_string ( $config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration
string. The format of the string specifies the Store subclass to be
instantiated as well as any required constructor arguments. These are separated
by a semicolon. An example configuration string for the DBI store would be:

 DBI;mymodel;DBI:mysql:database=rdf;user;password

The format of the constructor arguments (everything after the first ';') is
specific to the Store subclass.

=cut

sub new_with_string {
	my $proto	= shift;
	my $string	= shift;
	if (defined($string)) {
		my ($subclass, $config)	= split(/;/, $string, 2);
		my $class	= join('::', 'RDF::Trine::Store', $subclass);
		if (can_load(modules => { $class => 0 }) and $class->can('_new_with_string')) {
			return $class->_new_with_string( $config );
		} else {
			throw RDF::Trine::Error::UnimplementedError -text => "The class $class doesn't support the use of new_with_string";
		}
	} else {
		throw RDF::Trine::Error::MethodInvocationError;
	}
}


=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied
configuration hashref. This requires the the Store subclass to be
supplied with a C<storetype> key, while other keys are required by the
Store subclasses, please refer to each subclass for specific
documentation.

An example invocation for the DBI store may be:

  my $store = RDF::Trine::Store->new_with_config({
                storetype => 'DBI',
                name      => 'mymodel',
                dsn       => 'DBI:mysql:database=rdf',
                username  => 'dahut',
                password  => 'Str0ngPa55w0RD'
              });

=cut


sub new_with_config {
	my $proto		= shift;
	my $config	= shift;
	if (defined($config)) {
		my $class	= $config->{storeclass} || join('::', 'RDF::Trine::Store', $config->{storetype});
		if ($class->can('_new_with_config')) {
			return $class->_new_with_config( $config );
		} else {
			throw RDF::Trine::Error::UnimplementedError -text => "The class $class doesn't support the use of new_with_config";
		}
	} else {
		throw RDF::Trine::Error::MethodInvocationError;
	}
}


=item C<< new_with_object ( $object ) >>

Returns a new RDF::Trine::Store object based on the supplied opaque C<< $object >>.
If the C<< $object >> is recognized by an available backend as being sufficient
to construct a store object, the store object will be returned. Otherwise undef
will be returned.

=cut

sub new_with_object {
	my $proto	= shift;
	my $obj		= shift;
	foreach my $class (keys %STORE_CLASSES) {
		if ($class->can('_new_with_object')) {
			my $s	= $class->_new_with_object( $obj );
			if ($s) {
				return $s;
			}
		}
	}
	return;
}

=item C<< class_by_name ( $name ) >>

Returns the class of the storage implementation with the given name.
For example, C<< 'Memory' >> would return C<< 'RDF::Trine::Store::Memory' >>.

=cut

sub class_by_name {
	my $proto	= shift;
	my $name	= shift;
	foreach my $class (keys %STORE_CLASSES) {
		if (lc($class) =~ m/::${name}$/i) {
			return $class;
		}
	}
	return;
}

=item C<< temporary_store >>

Returns a new temporary triplestore (using appropriate default values).

=cut

sub temporary_store {
	return RDF::Trine::Store::Memory->new();
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

get_statements()	XXX maybe this should instead follow the quad semantics?
get_statements( s, p, o )
	return (s,p,o,nil) for all distinct (s,p,o)
get_statements( s, p, o, g )
	return all (s,p,o,g)

add_statement( TRIPLE )
	add (s, p, o, nil)
add_statement( TRIPLE, CONTEXT )
	add (s, p, o, context)
add_statement( QUAD )
	add (s, p, o, g )
add_statement( QUAD, CONTEXT )
	throw exception

remove_statement( TRIPLE )
	remove (s, p, o, nil)
remove_statement( TRIPLE, CONTEXT )
	remove (s, p, o, context)
remove_statement( QUAD )
	remove (s, p, o, g)
remove_statement( QUAD, CONTEXT )
	throw exception

count_statements()	XXX maybe this should instead follow the quad semantics?
count_statements( s, p, o )
	count distinct (s,p,o) for all statements (s,p,o,g)
count_statements( s, p, o, g )
	count (s,p,o,g)
