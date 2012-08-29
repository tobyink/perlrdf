package RDF::Trine::Exporter::CSV;

use Moose;
extends qw(RDF::Trine::Serializer::CSV);

my $warned;
sub BUILD {
	unless ($warned) {
		warn(
			"RDF::Trine::Exporter::CSV is deprecated; use RDF::Trine::Serializer::CSV.\n",
		);
		$warned++;
	}
}

1;
