use Test::More tests => 22;
use Test::Moose;
use Data::Dumper;
use Path::Class qw(dir file);
use URI;

use strict;
use warnings;

use RDF::Trine qw(iri blank literal variable);
use RDF::Trine::Namespace qw(xsd);

#use_ok 'RDF::Trine::Types';

{
    use RDF::Trine::Types qw(TrineNode);
    diag 'TrineNode';
    SKIP: {
        skip "Role refactoring from tobyink needs to be pulled", 3 unless RDF::Trine::Node::Literal->can('does');
        ok is_TrineNode(literal(5)), 'Literal isa TrineNode';
        ok is_TrineNode(iri('http://foo')), 'IRI isa TrineNode';
        ok is_TrineNode(blank), 'blank isa TrineNode';
        # todo coercion tests
    }
}

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
        $fixtures->{literals}->{$_} = literal({value => $fixtures->{values}->{$_}, datatype =>  $xsd->$_ });

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
    is_deeply TrineResource->coerce('someid'), iri('someid'), 'Str';
    is_deeply TrineResource->coerce(URI->new('http://foo.bar')), iri('http://foo.bar'), 'CPAN URI';
    is_deeply TrineResource->coerce(file('t/types.t')), iri('t/types.t'), 'Path::Class::File';
    is_deeply TrineResource->coerce(dir('t')), iri('t'), 'Path::Class::Dir';
    is_deeply TrineResource->coerce(\'123'), iri('data:,123'), 'ScalarRef';
    is_deeply TrineResource->coerce({
            scheme => 'http',
            host => 'foo.bar',
            path => 'baz',
        }), iri('http://foo.bar/baz'), 'HashRef';
}

{
    use RDF::Trine::Types qw(TrineNil);
    SKIP: {
        skip "Role refactoring from tobyink needs to be pulled", 1 unless RDF::Trine::Node::Nil->can('instance');
        diag "TrineNil";
        isa_ok TrineNil->coerce('foo'), 'RDF::Trine::Node::Nil', 'Nil';
    }
}

{
    use RDF::Trine::Types qw(UriStr);
    diag 'UriStr';
    is 'http://google.com/', UriStr->coerce({scheme=>'http',host=>'google.com'}), 'UriStr from TrineResource from HashRef';
}

{
    use RDF::Trine::Types qw(TrineBlankOrUndef);
    diag 'TrineBlankOrUndef';
    ok ! TrineBlankOrUndef->coerce(0), 'TrineBlankOrUndef on false value gives undef';
    isa_ok TrineBlankOrUndef->coerce(1), 'RDF::Trine::Node::Blank', 'TrineBlankOrUndef on true value gives blank node';
}

{
    use RDF::Trine::Types qw(TrineModel);
    diag 'TrineModel';
    my $temp_model = TrineModel->coerce;
    isa_ok $temp_model, 'RDF::Trine::Model', 'Coercion from undef yields model';
    # my $w3c_model = TrineModel->coerce('http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf');
    my $w3c_model = TrineModel->coerce('http://www.w3.org/2000/10/rdf-tests/rdfcore/unrecognised-xml-attributes/test001.rdf');
    isa_ok $w3c_model, 'RDF::Trine::Model', 'Coercion from URI yields model';
    is $w3c_model->size, 2, '2 Statement in the model';
}

{
    use RDF::Trine::Types qw(TrineStore);
    diag 'TrineStore';
    my $temp_store = TrineStore->coerce;
    does_ok $temp_store, 'RDF::Trine::Store::API', 'Undef';
    my $temp_store2 = TrineStore->coerce({storetype=>'Memory', sources=>[]});
    does_ok $temp_store2, 'RDF::Trine::Store::API', 'HashRef';
    warn "Need to test new_with_object somehow, but that requires setting up the env";
    warn "Need to test new somehow, but that requires setting up the env";
}

{
    use RDF::Trine::Types qw(TrineNamespace);
    diag 'TrineNamespace';
    my $ns = TrineNamespace->coerce('http://foo.bar/onto#');
    isa_ok $ns, 'RDF::Trine::Namespace';
}
exit;
