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
    is_deeply iri('someid'), TrineResource->coerce('someid'), 'Str';
    is_deeply iri(URI->new('http://foo.bar')), TrineResource->coerce('http://foo.bar'), 'CPAN URI';
    is_deeply iri(file('t/types.t')->stringify), TrineResource->coerce(file('t/types.t')), 'Path::Class::File';
    is_deeply iri(dir('t')->stringify), TrineResource->coerce(dir('t')), 'Path::Class::Dir';

}
