package RDF::Endpoint::Server;

use strict;
use warnings;

use RDF::Endpoint;
use base qw(HTTP::Server::Simple::CGI HTTP::Server::Simple::Static);

sub new {
	my $class		= shift;
	my %args		= @_;
	
	my $port		= $args{ Port };
	my $dsn			= $args{ DBServer };
	my $user		= $args{ DBUser };
	my $pass		= $args{ DBPass };
	my $model		= $args{ Model };
	
	my $self		= $class->SUPER::new( $port );
	my $endpoint	= RDF::Endpoint->new( $model, $dsn, $user, $pass );
	$endpoint->init();
	$self->{endpoint}	= $endpoint;
	return $self;
}

sub handle_request {
	my $self	= shift;
	my $cgi		= shift;
	my $endpoint	= $self->{endpoint};
	binmode( \*STDOUT, ':utf8' );
	
	my $port	= $self->port;
	my $host	= $self->host;
	my $path	= $ENV{REQUEST_URI};
	my $prefix	= "http://${host}:${port}";
	my $url		= $prefix . $path;
	
	if ($path =~ qr'^/sparql') {
		my $sparql	= $cgi->param('query');
		if ($sparql) {
			$endpoint->run_query( $cgi, $sparql );
		} else {
			$self->error( 400, 'Bad Request', 'No query.' );
		}
	} elsif ($path =~ qr'^/query/(\w+)') {
		my $query	= $endpoint->run_saved_query( $cgi, $1 );
	} else {
		if ($path =~ qr</$>) {
			my $url	= "${prefix}${path}index.html";
			$self->redir( 303, 'See Other', $url );
		} elsif ($path =~ qr[^/admin$]) {
			# POSTing data for the admin page
			warn 'admin post';
			$endpoint->handle_admin_post( $cgi, $host, $port );
		} elsif ($path =~ qr[^/admin/]) {
			if ($path =~ qr[^/admin/index.html$]) {
				$endpoint->admin_index($cgi);
			} else {
				unless ($self->serve_static($cgi, "./docs")) {
					$self->error( 403, 'Forbidden', 'You do not have permission to access this resource' );
				}
			}
		} else {
			unless ($self->serve_static($cgi, "./docs")) {
				$self->error( 404, 'Not Found', 'The requested resource could not be found' );
			}
		}
	}
}

sub error {
	my $self	= shift;
	my $code	= shift;
	my $name	= shift;
	my $error	= shift;
	print "HTTP/1.1 ${code} ${name}\n\n<html><head><title>${name}</title></head><body><h1>${name}</h1><p>${error}</p></body></html>";
	return;
}

sub redir {
	my $self	= shift;
	my $code	= shift;
	my $message	= shift;
	my $url		= shift;
	print "HTTP/1.1 ${code} ${message}\nLocation: ${url}\n\n";
	return;
}

1;

__END__