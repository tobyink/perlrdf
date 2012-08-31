package RDF::Trine::Serializer::RDFXML;

use constant media_types => [qw( application/rdf+xml )];
use RDF::Trine;
use RDF::Trine::FormatRegistry -register_serializer;

use Moose;
with qw(
	RDF::Trine::Serializer::API::Graph
);

has [qw/ namespaces scoped_namespaces base_uri /] => (is => 'rw');

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use TryCatch;

use RDF::Trine;
use RDF::Trine::Statement::Triple;

sub BUILDARGS {
	my $class	= shift;
	my %args	= @_;
	my $self = +{ namespaces => { 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' => 'rdf' } };
	if (my $ns = $args{namespaces}) {
		my %ns		= %{ $ns };
		my %nsmap;
		while (my ($ns, $uri) = each(%ns)) {
			for (1..2) {
				$uri	= $uri->uri_value if (blessed($uri));
			}
			$nsmap{ $uri }	= $ns;
		}
		@{ $self->{namespaces} }{ keys %nsmap }	= values %nsmap;
	}
	if ($args{base}) {
		$self->{base_uri} = $args{base};
	}
	if ($args{base_uri}) {
		$self->{base_uri} = $args{base_uri};
	}
	if ($args{scoped_namespaces}) {
		$self->{scoped_namespaces} = $args{scoped_namespaces};
	}
	return $self;
}

sub _serialize_graph {
	my ($self, $iter, $fh) = @_;
	
	my $ns = $self->_top_xmlns();
	my $base_uri = '';
	if ($self->base_uri) {
		$base_uri = "xml:base=\"".$self->base_uri."\" ";
	}
	printf {$fh}
		qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF %sxmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"%s>\n],
		$base_uri,
		$ns;
	
	my $st = $iter->next;
	my @statements;
	push(@statements, $st) if blessed($st);
	while (@statements) {
		my $st	= shift(@statements);
		my @samesubj;
		push(@samesubj, $st);
		my $subj	= $st->subject;
		while (my $row = $iter->next) {
			if ($row->subject->equal( $subj )) {
				push(@samesubj, $row);
			} else {
				push(@statements, $row);
				last;
			}
		}
		
		print {$fh} $self->_statements_same_subject_as_string( @samesubj );
	}
	
	print {$fh} qq[</rdf:RDF>\n];
}

sub _statements_same_subject_as_string {
	my $self		= shift;
	my @statements	= @_;
	my $s			= $statements[0]->subject;
	
	my $id;
	if ($s->isa('RDF::Trine::Node::Blank')) {
		my $b	= $s->blank_identifier;
		$id	= qq[rdf:nodeID="$b"];
	} else {
		my $i	= $s->uri_value;
		for ($i) {
			s/&/&amp;/g;
			s/</&lt;/g;
			s/"/&quot;/g;
		}
		$id	= qq[rdf:about="$i"];
	}
	
	my $counter	= 1;
	my %namespaces	= %{ $self->namespaces };
	my $string	= '';
	foreach my $st (@statements) {
		my (undef, $p, $o)	= $st->nodes;
		my %used_namespaces;
		my ($ns, $ln);
		try {
			($ns,$ln)	= $p->qname;
		} catch ($e) {
			my $uri	= $p->uri_value;
			RDF::Trine::Exception->throw(
				message => "Can't turn predicate $uri into a QName.",
			);
		};
		$used_namespaces{ $ns }++;
		unless (exists $namespaces{ $ns }) {
			$namespaces{ $ns }	= 'ns' . $counter++;
		}
		my $prefix	= $namespaces{ $ns };
		my $nsdecl	= '';
		if ($self->scoped_namespaces) {
			$nsdecl	= qq[ xmlns:$prefix="$ns"];
		}
		if ($o->isa('RDF::Trine::Node::Literal')) {
			my $lv		= $o->literal_value;
			for ($lv) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			my $lang	= $o->literal_value_language;
			my $dt		= $o->literal_datatype;
			my $tag	= join(':', $prefix, $ln);
			
			if ($lang) {
				$string	.= qq[\t<${tag}${nsdecl} xml:lang="${lang}">${lv}</${tag}>\n];
			} elsif ($dt) {
				$string	.= qq[\t<${tag}${nsdecl} rdf:datatype="${dt}">${lv}</${tag}>\n];
			} else {
				$string	.= qq[\t<${tag}${nsdecl}>${lv}</${tag}>\n];
			}
		} elsif ($o->isa('RDF::Trine::Node::Blank')) {
			my $b	= $o->blank_identifier;
			for ($b) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			$string	.= qq[\t<${prefix}:$ln${nsdecl} rdf:nodeID="$b"/>\n];
		} else {
			my $u	= $o->uri_value;
			for ($u) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			$string	.= qq[\t<${prefix}:$ln${nsdecl} rdf:resource="$u"/>\n];
		}
	}
	
	$string	.= qq[</rdf:Description>\n];
	
	# rdf namespace is already defined in the <rdf:RDF> tag, so ignore it here
	my %seen	= %{ $self->namespaces };
	my @ns;
	foreach my $uri (sort { $namespaces{$a} cmp $namespaces{$b} } grep { not($seen{$_}) } (keys %namespaces)) {
		my $ns	= $namespaces{$uri};
		my $str	= ($ns eq '') ? qq[xmlns="$uri"] : qq[xmlns:${ns}="$uri"];
		push(@ns, $str);
	}
	my $ns	= join(' ', @ns);
	if ($ns) {
		return qq[<rdf:Description ${ns} $id>\n] . $string;
	} else {
		return qq[<rdf:Description $id>\n] . $string;
	}
}

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= {};
	
	my $ns		= $self->_top_xmlns();
	my $base_uri	= '';
	if ($self->base_uri) {
		$base_uri = "xml:base=\"".$self->base_uri."\" ";
	}
	my $string	= qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF $base_uri$ns>\n];
	$string		.= $self->__serialize_bounded_description( $model, $node, $seen );
	$string	.= qq[</rdf:RDF>\n];
	return $string;
}

sub __serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	
	my $string	= '';
	my $st		= RDF::Trine::Statement::Triple->new( $node, map { RDF::Trine::Node::Variable->new($_) } qw(p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(p ASC o ASC) ] );
	
	my @bindings	= $iter->get_all;
	if (@bindings) {
		my @samesubj	= map { RDF::Trine::Statement::Triple->new( $node, $_->{p}, $_->{o} ) } @bindings;
		my @blanks		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Blank') } map { $_->{o} } @bindings;
		$string			.= $self->_statements_same_subject_as_string( @samesubj );
		foreach my $object (@blanks) {
			$string	.= $self->__serialize_bounded_description( $model, $object, $seen );
		}
	}
	return $string;
}

sub _top_xmlns {
	my $self	= shift;
	my $namespaces	= $self->namespaces;
	my @keys		= sort { $namespaces->{$a} cmp $namespaces->{$b} } keys %$namespaces;
	return '' if ($self->scoped_namespaces);
	
	my @ns;
	foreach my $v (@keys) {
		next if ($v eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
		my $k	= $namespaces->{$v};
		if (blessed($v)) {
			$v	= $v->uri_value;
		}
		my $str	= ($k eq '') ? qq[xmlns="$v"] : qq[xmlns:$k="$v"];
		push(@ns, $str);
	}
	my $ns		= join(' ', @ns);
	if (length($ns)) {
		$ns	= " $ns";
	}
	return $ns;
}

__PACKAGE__->meta->make_immutable;
1;
