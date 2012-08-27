use Test::More tests => 8;
use Test::Moose;
use Data::Dumper;
use Path::Class qw(dir file);
use URI;

use strict;
use warnings;

use RDF::Trine qw(iri blank literal variable);
use RDF::Trine::Namespace qw(xsd);

use_ok 'RDF::Trine::Types';

{
    use RDF::Trine::Types qw(TrineLiteral);
    diag 'TrineLiteral';
    my $fixtures = {
        values => {
            int => 23,
            numeric => 23.01,
            string  => 'string',
        },
        literals => {},
        coerced => {},
    };
    for (keys %{$fixtures->{values}}) {

        # with RDF::Trine::literal
        $fixtures->{literals}->{$_} = literal($fixtures->{values}->{$_}, undef, $xsd->$_);

        # with RDF::Trine::Types
        $fixtures->{coerced}->{$_} = TrineLiteral->coerce($fixtures->{values}->{$_});
    }
    for (keys %{$fixtures->{values}}) {
        is_deeply $fixtures->{literals}->{$_}, $fixtures->{coerced}->{$_}, "TrineLiteral: $_";
    }
}

{
    use RDF::Trine::Types qw(TrineResource);
    diag 'TrineResource';
    is_deeply iri('someid'), TrineResource->coerce('someid'), 'Str';
    is_deeply iri(URI->new('http://foo.bar')), TrineResource->coerce('http://foo.bar'), 'CPAN URI';
    is_deeply iri('t/types.t'), TrineResource->coerce(file('t/types.t')), 'Path::Class::File';
    is_deeply iri('t'), TrineResource->coerce(dir('t')), 'Path::Class::Dir';
    is_deeply iri('data:,123'), TrineResource->coerce(\'123'), 'ScalarRef';
    is_deeply iri('http://foo.bar/baz'), TrineResource->coerce({
            scheme => 'http',
            host => 'foo.bar',
            path => 'baz',
        }), 'HashRef';
}

{
    use RDF::Trine::Types qw(TrineModel);
    diag 'TrineModel';
    my $temp_model = TrineModel->coerce;
    isa_ok $temp_model, 'RDF::Trine::Model', 'Coercion from undef yields model';
    my $toby_model = TrineResource->coerce('http://tobyinkster.co.uk/');
    warn Dumper $toby_model;
}
