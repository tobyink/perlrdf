use Test::More tests => 2;
BEGIN { use_ok('RDF::Trine::Serializer::SparqlXML') };

use strict;
use warnings;

use RDF::Trine qw(iri blank);

my $store	= RDF::Trine::Store->temporary_store();
my $model	= RDF::Trine::Model->new( $store );

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $graph1	= iri('http://example.com/graph1');
my $graph2	= blank('graph2');
my $page	= iri('http://kasei.us/');
my $g		= blank('greg');
my $st0		= RDF::Trine::Statement::Triple->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement::Triple->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement::Quad->new( $g, $foaf->homepage, $page, $graph1 );
my $st3		= RDF::Trine::Statement::Quad->new( $page, $rdf->type, $foaf->Document, $graph2 );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3);

my $ser = RDF::Trine::Serializer->new('application/sparql-results+xml');

like(
	$ser->model_to_string($model),
	qr{<binding name="object"><literal>Greg</literal></binding>},
);
