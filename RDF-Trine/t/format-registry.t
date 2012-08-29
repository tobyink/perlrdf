use Test::More tests=>35;
use ok RDF::Trine::FormatRegistry;
use Data::Dumper;
use ok RDF::Trine::Parser;
use ok RDF::Trine::Serializer;

{
    my $reg = RDF::Trine::FormatRegistry->instance;
    isa_ok $reg, 'RDF::Trine::FormatRegistry';
    is scalar($reg->all_formats), 14, '14 formats';
    is scalar($reg->known_names), 14, '14 formats with name';
    is scalar($reg->known_format_uris), 14, '14 formats with format URI';
    is scalar($reg->known_media_types), 19, '19 media types';

    diag "parsers";
    is scalar($reg->known_media_types_with_parsers), 8, '8 media types with parsers';
    my %parsers_expected = (
        'text/turtle'            => 'RDF::Trine::Parser::Turtle',
        'application/turtle'     => 'RDF::Trine::Parser::Turtle',
        'application/x-turtle'   => 'RDF::Trine::Parser::Turtle',
        'text/plain'             => 'RDF::Trine::Parser::NTriples',
        'text/x-ntriples'        => 'RDF::Trine::Parser::NTriples',
        'application/xhtml+xml'  => 'RDF::Trine::Parser::RDFa',
        'application/x-rdf+json' => 'RDF::Trine::Parser::RDFJSON',
        'application/json'       => 'RDF::Trine::Parser::RDFJSON',
    );
    while (my ($type,$parser_expected) = each %parsers_expected) {
        my $parser_found = $reg->find_format_by_media_type( $type )->parsers->[0];
        is $parser_found, $parser_expected, "$type => $parser_found";
    }

    diag "serializers";
    is scalar($reg->known_media_types_with_serializers), 6, '6 media types with serializers';
    my %serializers_expected = (
        'text/plain' => 'RDF::Trine::Serializer::NTriples',
        'text/x-ntriples' => 'RDF::Trine::Serializer::NTriples',
        'application/x-rdf+json' => 'RDF::Trine::Serializer::RDFJSON',
        'application/json' => 'RDF::Trine::Serializer::RDFJSON',
        'text/x-nquads' => 'RDF::Trine::Serializer::NQuads',
        'text/tab-separated-values' => 'RDF::Trine::Serializer::TSV',
    );
    while (my ($type,$serializer_expected) = each %serializers_expected) {
        my $serializer_found = $reg->find_format_by_media_type( $type )->serializers->[0];
        is $serializer_found, $serializer_expected, "$type => $serializer_found";
    }

    diag "capabilities";
    is scalar(@{[$reg->find_format_by_capabilities]}), 14, "14 formats with empty search hash";
    is scalar(@{[$reg->find_format_by_capabilities(triples=>1)]}), 14, "14 formats: (triples=>1)";
    is scalar(@{[$reg->find_format_by_capabilities({triples=>1})]}), 14, "14 formats: {triples=>1}";
    is scalar(@{[$reg->find_format_by_capabilities(quads=>1)]}), 6, "6 formats: [quads]";
    is scalar(@{[$reg->find_format_by_capabilities(result_sets=>1)]}), 4, "4 formats: [result_sets]";
    is scalar(@{[$reg->find_format_by_capabilities(magic_numbers=>1)]}), 5, "5 formats: [magic_numbers]";
    is scalar(@{[$reg->find_format_by_capabilities(booleans=>1)]}), 4, "4 formats: [booleans]";
    is scalar(@{[$reg->find_format_by_capabilities(booleans=>1,quads=>1)]}), 4, "4 formats: [booleans,quads]";
    is scalar(@{[$reg->find_format_by_capabilities(quads=>1,magic_numbers=>1)]}), 1, "1 formats: [quads,magic_numbers]";
    is scalar(@{[$reg->find_format_by_capabilities(quads=>1,triples=>1)]}), 6, "6 formats: [quads,triples]";
    is scalar(@{[$reg->find_format_by_capabilities(quads=>1,triples=>1,magic_numbers=>1,booleans=>1,result_sets=>1,booleans=>1)]}), 1, "1 formats: [quads,triples,magic_numbers,booleans,result_sets,booleans]";

}
