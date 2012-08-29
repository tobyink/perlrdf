# RDF::Trine::Types
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Types - MooseX::Types for RDF::Trine 

=head1 VERSION

This document describes RDF::Trine::Types version 1.000

=head2 SYNOPSIS

    use RDF::Trine qw(literal)
    use RDF::Trine::Types qw(TrineLiteral TrineNode)

    # type checking
    $val1 = 33;
    $val2 = literal($val1);
    is_TrineLiteral($val1) # 0
    is_TrineLiteral($val2) # 1


    # coercion where available
    my $literal1 = TrineLiteral->coerce(66); # literal(66)
    my $literal2 = TrineLiteral->coerce($literal1); # $literal1 == $literal2

=head2 DESCRIPTION

TODO

=cut
package RDF::Trine::Types;
use strict;
use URI;
use RDF::Trine::Namespace qw(xsd);
use MooseX::Types::URI Uri => { -as => 'MooseX__Types__URI__Uri' };
use MooseX::Types::Moose qw{:all};
use MooseX::Types::Path::Class qw{File Dir};
use MooseX::Types -declare => [
    'TrineNode',
    'TrineBlank',
    'TrineLiteral',
    'TrineNil',
    'TrineResource',

    'ArrayOfTrineResources',
    'ArrayOfTrineNodes',
    'ArrayOfTrineLiterals',

    'HashOfTrineResources',
    'HashOfTrineNodes',
    'HashOfTrineLiterals',

    'TrineLiteralOrTrineResource',
    'TrineBlankOrUndef',

    'TrineStore',
    'TrineModel',

    'TrineNamespace',
    'TrineFormat',

    'CPAN_URI',
    'UriStr',
    'LanguageTag',
    ];

our ($VERSION);
BEGIN {
	$VERSION	= '1.000';
}

=head2 TYPE CONSTRAINTS

=cut


=head3 TrineNode

Evertything that does RDF::Trine::Node::API

=cut

role_type TrineNode, { role => 'RDF::Trine::Node::API'  };

=head3 TrineResource 

A RDF::Trine::Node::Resource

Can be coerced from

=over 4

=item * String

=item * URI (GAAS' CPAN URI module)

=item * Path::Class::File

=item * Moosex::Types::Path::Class::File

=item * Path::Class::Dir

=item * Moosex::Types::Path::Class::Dir

=item * ScalarRef (for 'data:' URIs, i.e. base64 encoded data, like images)

=item * HashRef (using URI::FromHash)

=back

=cut

class_type TrineResource, { class => 'RDF::Trine::Node::Resource' };

=head3 TrineLiteral

Coercion from Int, Bool, Num, Str

=cut

class_type TrineLiteral, { class => 'RDF::Trine::Node::Literal' };

=head3 TrineNil

Coercion from anything

=cut

class_type TrineNil, { class => 'RDF::Trine::Node::Nil' };

=head3 TrineBlank

No Coercion

=cut

class_type TrineBlank, { class => 'RDF::Trine::Node::Blank' };

=head3 TrineModel

Coercion from

=over 4

=item * Undef (temporary_model)

=item * Anything that can be coerced to UriStr (by using RDF::Trine::Parser->parse_url_into_model)

=back

=cut

class_type TrineModel, { class => 'RDF::Trine::Model' };

=head3 TrineStore

Everything that does RDF::Trine::Store::API

No Coercion

=cut

role_type TrineStore, { role => 'RDF::Trine::Store::API' };

=head3 TrineNamespace

Coercion delegates to new

=cut

class_type TrineNamespace, { class => 'RDF::Trine::Namespace' };

=head3 TrineFormat

Coerces

=over 4

=item Str (via RDF::Trine::FomatRegistry lookup)

=back

=cut

class_type TrineFormat, { class => 'RDF::Trine::Format' };

coerce( TrineFormat,
    from Str, via { RDF::Trine::FormatRegistry->instance->find_format($_) },
    from ArrayRef, via { RDF::Trine::FormatRegistry->instance->find_format($_->[0], $_->[1]) },
);

=head3 CPAN_URI

A URI as in the URI CPAN module by GAAS

No Coercion (see MooseX::Types::URI for that)

=cut

class_type CPAN_URI, { class => 'URI' };

=head3 TrineBlankOrUndef

Coerces from

=over 4

=item * false value (undef)

=item * true value (Blank Node)

=back

=cut

subtype TrineBlankOrUndef, as Maybe[TrineBlank];

=head3 ArrayOfTrineResources

Coerces from

=over 4

=item * RDF::Trine::Node::Resource (by wrapping in an ArrayRef)

=item * Array (by coercing all values to TrineResource)

=item * something (by coercing something to TrineResource and wrapping it in an ArrayRef)

=back

=cut

subtype ArrayOfTrineResources, as ArrayRef[TrineResource];

=head3 ArrayOfTrineNodes

No coercion

=cut

subtype ArrayOfTrineNodes, as ArrayRef[TrineNode];

=head3 HashOfTrineResources

No coercion

=cut

subtype HashOfTrineResources, as HashRef[TrineResource];

=head3 ArrayOfTrineLiterals

No coercion

=cut

subtype ArrayOfTrineLiterals, as ArrayRef[TrineLiteral];

=head3 HashOfTrineLiterals

No coercion

=cut

subtype HashOfTrineLiterals, as HashRef[TrineLiteral];

=head3 HashOfTrineNodes

No coercion

=cut

subtype HashOfTrineNodes, as HashRef[TrineNode];

=head3 UriStr

Value is coerced to TrineResource, than stringified

=cut

subtype UriStr, as Str;

#-----------------------------------------------------------------------------#
# COERCIONS
#-----------------------------------------------------------------------------#
=head3 LanguageTag

No coercion

=cut

subtype LanguageTag, as Str, where { length $_ };

coerce( TrineBlankOrUndef,
    from Bool, via { return undef unless $_; RDF::Trine::Node::Blank->new },
);

coerce (TrineResource,
    from Str, via { RDF::Trine::Node::Resource->new( $_ ) },
    from CPAN_URI, via { RDF::Trine::Node::Resource->new( $_->as_string ) },
);
for (File, Dir, ScalarRef, HashRef){
    coerce( TrineResource,
        from $_,
            via {
                my $str = MooseX__Types__URI__Uri->coerce( $_ );
                $str = $str->as_string if ref $str;
                RDF::Trine::Node::Resource->new($str )
            }
    );
};

coerce TrineNil,
    from Value, via { RDF::Trine::Node::Nil->instance };

coerce( ArrayOfTrineLiterals,
    from TrineLiteral, via { [ $_ ] },
    from ArrayRef, via { my $u = $_; [map {TrineLiteral->coerce($_)} @$u] },
    from Value, via { [ TrineLiteral->coerce( $_ ) ] },
);

coerce( ArrayOfTrineResources,
    # from Str, via { [ TrineResource->coerce( $_ ) ] },
    from TrineResource, via { [ $_ ] },
    from ArrayRef, via { my $u = $_; [map {TrineResource->coerce($_)} @$u] },
    from Value, via { [ TrineResource->coerce( $_ ) ] },
);

coerce (TrineNode,
    from TrineBlank, via { $_ },
    from TrineResource, via { $_ },
    from Defined, via {TrineResource->coerce( $_ )},
);

coerce (UriStr,
    from Defined, via { TrineResource->coerce( $_)->uri },
);

coerce( TrineModel,
    from Undef, via { RDF::Trine::Model->temporary_model },
    from Str, via {
        my $m = TrineModel->coerce;
        my $uri = UriStr->coerce($_);
        my $ok = RDF::Trine::Parser->parse_url_into_model( $uri, $m ); #, content_cb => sub { warn Dumper @_ } );
        return $m;
    },
);

coerce( TrineStore,
    from Undef, via { RDF::Trine::Store->temporary_store },
    from Str, via { RDF::Trine::Store->new_with_string( $_ ) },
    from HashRef, via { RDF::Trine::Store->new_with_config( $_ ) },
    from Object, via { RDF::Trine::Store->new_with_object( $_ ) },
    from Defined, via { RDF::Trine::Store->new( $_ ) },
);
coerce( TrineLiteral,
    from Int   , via { RDF::Trine::Node::Literal->new({ value=> $_  , datatype => $xsd->int     }); },
    from Bool  , via { RDF::Trine::Node::Literal->new({ value => $_ , datatype => $xsd->boolean }); },
    from Num   , via { RDF::Trine::Node::Literal->new({ value => $_ , datatype => $xsd->numeric }); },
    from Str   , via { RDF::Trine::Node::Literal->new({ value => $_ , datatype => $xsd->string  }); },
    from Value , via { RDF::Trine::Node::Literal->new({ value => $_ }) },
);
coerce( TrineNamespace,
    from Defined, via { RDF::Trine::Namespace->new( UriStr->coerce($_) ) }
);

1;

__END__

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Konstantin Baierer  C<< <kba@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2012 Konstantin Baierer. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut
