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

sub canonical_media_type { shift->media_types->[0] // 'application/octet-stream' }

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

__END__

=head1 NAME

RDF::Trine::Format - a file format that RDF::Trine knows about

=head DESCRIPTION

RDF::Trine::Format objects provide places to hold information about file
formats, including a list of known parsers and serializers for that format.

=head2 Attributes

=over

=item C<< name >>

The preferred name for the format.

=item C<< names >>

Array ref of aliases for the format (including the preferred name).

=item C<< format_uri >>

A single string URI to identify the format. Required.

=item C<< media_types >>

An array ref of media types that may identify the format. The first is 
considered the canonical one.

=item C<< extensions >>

File name "extensions" associated with the format.

=item C<< magic_numbers >>

Something that can be used as the right hand side of a smart match for
format sniffing. Usually an arrayref of regular expressions.

 my $chunk = substr($file_contents, 0, 1024);
 foreach my $fmt (@{ $registry->formats }) {
     next unless $fmt->has_magic_numbers;
     if ($chunk ~~ $fmt->magic_numbers) {
         my $parser = $fmt->parsers->[0]->new;
         $parser->parse($base_uri, $file_contents, \&handler);
     }
 }

=item C<< triples >> 

Whether the file format is capable of holding triples.

=item C<< quads >> 

Whether the file format is capable of holding quads.

=item C<< result_sets >>

Whether the file format is capable of holding SPARQL result sets.

=item C<< booleans >>

Whether the file format is capable of holding boolean values.

=item C<< parsers >>

Array ref of class names.

=item C<< serializers >>

Array ref of class names.

=back

=head2 Methods

=over

=item C<< add_media_type($mt) >>

=item C<< all_media_types >>

=item C<< handles_media_type($mt) >>

=item C<< canonical_media_type >>

=item C<< add_extension($ext) >>

=item C<< all_extensions >>

=item C<< has_magic_numbers >>

=item C<< matches_opts(\%features) >>

Used by C<find_format_by_capabilities>.

=item C<< register_parser($classname) >>

=item C<< register_serializer($classname) >>

=back

