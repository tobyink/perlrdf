package RDF::Trine::Parser::Turtle::Redland;
use Moose;
use Carp;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

use RDF::Trine qw(literal);
use RDF::Trine::Statement::Triple;
use RDF::Trine::Error;

use constant media_types => [
    'application/x-turtle',
    'application/turtle',
    'text/turtle'
];

use RDF::Trine::FormatRegistry '-register_parser';

with (
    'RDF::Trine::Parser::API',
    'RDF::Trine::Parser::API::Redland'
);

our ($VERSION, $HAVE_REDLAND_PARSER);

BEGIN {
	$VERSION	= '1.000';
	unless ($ENV{RDFTRINE_NO_REDLAND}) {
		eval "use RDF::Redland 1.000701;";
		unless ($@) {
			$HAVE_REDLAND_PARSER	= 1;
		}
	}
}

sub _build_redland_parser {
    return RDF::Redland::Parser->new('turtle');
}

sub BUILD {
	unless ($HAVE_REDLAND_PARSER) {
		throw RDF::Trine::Error
			-text => "Failed to load RDF::Redland >= 1.0.7.1";
	}
}

#use base qw(RDF::Trine::Parser::Redland);
#sub new { shift->SUPER::new( @_, name => 'turtle' ) }

