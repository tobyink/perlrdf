package RDF::Trine::Format;

use Moose;
use MooseX::Types::Moose qw(Str ArrayRef Any Bool ClassName);
use RDF::Trine::Types qw(UriStr);
use namespace::autoclean;

has name => (
	is         => 'ro',
	isa        => Str,
	predicate  => '_has_name',
	lazy_build => 1,
);

sub _build_name { my $self = shift; $self->names->[0] }

has names => (
	is         => 'ro',
	isa        => ArrayRef[ Str ],
	lazy_build => 1,
);

sub _build_names { my $self = shift; $self->_has_name ? [ $self->name ] : [] }

has format_uri => (
	is         => 'ro',
	isa        => UriStr,
	required   => 1,
);

has media_types => (
	is         => 'ro',
	isa        => ArrayRef[ Str ],
	traits     => ['Array'],
	handles    => {
		add_media_type  => 'push',
		all_media_types => 'elements',
	},
);

sub handles_media_type {
	my ($self, $mt) = @_;
	!!( grep { lc($mt) eq lc($_) } $self->all_media_types )
}

has extensions => (
	is         => 'ro',
	isa        => ArrayRef[ Str ],
	traits     => ['Array'],
	handles    => {
		add_extension  => 'push',
		all_extensions => 'elements',
	},
);

# magic_numbers are for format sniffing...
#
#   my $chunk = substr($file_contents, 0, 1024);
#   foreach my $fmt (@{ $registry->formats })
#   {
#       next unless $fmt->has_magic_numbers;
#       if ($chunk ~~ $fmt->magic_numbers) {
#         my $parser = $fmt->parsers->[0]->new;
#         $parser->parse($base_uri, $file_contents, \&handler);
#       }
#   }
#

has magic_numbers => (
	is         => 'ro',
	isa        => Any,
	predicate  => 'has_magic_numbers',
);

has [qw/ triples quads result_sets booleans /] => (
	is        => 'ro',
	isa       => Bool,
	default   => 0,
);

sub matches_opts {
	my $self = shift;
	my %opts = @_==1 ? %{$_[0]} : @_;
	while (my ($k, $v) = each %opts)
	{
		return if $v && !$self->$k;
	}
	return 1;
}

has [qw/ parsers serializers /] => (  # ?? validators ??
	is         => 'ro',
	isa        => ArrayRef[ ClassName ],
	default    => sub { [] },
);

sub register_parser {
	my ($self, $p) = @_;
	return if grep { $_ eq $p } @{ $self->parsers };
	push @{ $self->parsers }, $p;
}

sub register_serializer {
	my ($self, $p) = @_;
	return if grep { $_ eq $p } @{ $self->serializers };
	push @{ $self->serializers }, $p;
}

1;
