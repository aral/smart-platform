package RSP::Transaction::Plack;

use Moose;

extends 'RSP::Transaction';

use Plack::Response;

use Encode;
use utf8;

has hostname => (is => 'rw');
has request => (is => 'rw');
has response => (is => 'rw');

use Plack::Request;
use IO::Handle::Iterator; 

sub app {
    return sub {
        my ($env) = @_;
        my $trans = RSP::Transaction::Plack->new();
        my $req = Plack::Request->new($env);
        $trans->request($req);
        $trans->hostname( $req->uri->host );
        $trans->response(Plack::Response->new());
        $trans->process_transaction();
        return $trans->response->finalize;
    };
}

sub encode_body {
    my $self = shift;
    my $body = shift;

    ##
    ## if we have a simple body string, use that, otherwise
    ##  we need to be a bit more clever
    ##
    if (!ref($body)) {
        my $content = encode_utf8($body);
        $self->response->content_length(bytes::length($content));
        $self->response->body( $content );
    } else {
        if( blessed($body) ){
            if ( $body->isa('JavaScript::Function') ) {
                ## it's a javascript function, call it and use the
                ## returned data
                my $content = $body->as_function->();
                if ($@) { die $@ };
                $content = encode_utf8($content);
                $self->response->content_length(bytes::length($content));
                $self->response->body( $content );
            } elsif ( $body->isa('RSP::JSObject') || ($body->can('does') && $body->does('RSP::Role::JSObject')) ) {
                if ( $body->isa('RSP::JSObject::File') ) {
                    open(my $fh, $body->fullpath) or die "Could not open file: $!";
                    $self->response->content_length($body->size);
                    $self->response->body($fh);
                } else {
                    ##
                    ## it's an object that exists in both JS and Perl, convert it
                    ##  to it's stringified form, with a hint for the content-type.
                    ##
                    my $content = $body->as_string( type => $self->response->headers->content_type );
                    $self->response->body(encode_utf8($content));
                }
            } elsif  ( $body->isa('JavaScript::Generator') ) {
                my $io = IO::Handle::Iterator->new(sub {
                   my $content = $body->next;
                   my $size = bytes::length( $content );
                   my $bwreport = RSP::Consumption::Bandwidth->new();
                   $bwreport->count($size);
                   $bwreport->host( $self->hostname );
                   $bwreport->uri( $self->url );
                   $self->consumption_log( $bwreport );
                   
                   return $content ? $content : undef;
                });

                $self->response->body($io);
                
            }
        } else {
            die "Invalid response body type\n";
        }
    }
}

sub encode_array_response {
    my $self = shift;
    my $response = shift;
    my @resp = @$response;
    my ($code, $headers, $body) = @resp;
    $self->response->code( $code );

    my @headers = @$headers;
    while( my $key = shift @headers ) {
        my $value = shift @headers;
        ## why do we need to special case this?
        $self->response->headers->push_header( $key, $value );
    }

  $self->encode_body( $body );
}

##
## turns the response from the code into the Mojo::Message object
## that the web server needs.
##
sub encode_response {
    my $self = shift;
    my $response = shift;

    if ( ref( $response ) && ref( $response ) eq 'ARRAY' ) {
        ## we're encoding a list...
        $self->encode_array_response( $response );
    } else {
        ## we're encoding a single thing...
        $self->response->headers->content_type( 'text/html' );
        $self->response->code( 200 );
        $self->encode_body( $response );
    }

    $self->response->headers->remove_header('X-Powered-By');
    $self->response->headers->remove_header('Server');
    $self->response->headers->push_header("Joyent Smart Platform (Plack)/$RSP::VERSION");

=for comment
    if ( $self->response->headers->header('Transfer-Encoding') &&
        $self->response->headers->header('Transfer-Encoding') eq 'chunked' ) {
        $self->response->headers->remove_header('Content-Length');
    } else {
        if ( !$self->response->headers->content_length) {
            use bytes;
            $self->response->headers->content_length(
	        length($self->response->body)
            );
        }
    }
=cut

}

##
## terminates the transaction
##
#sub end {
#    my $self = shift;
#    my $post_callback = shift;
#
#    if ($post_callback || !($self->response->headers->header('Transfer-Encoding') && $self->response->headers->header('Transfer-Encoding') eq "chunked")) {
#        $self->report_consumption;
#    }
#
#    $self->SUPER::end();
#
#    $self->cleanup_js_environment;
#}

#sub process_transaction {
#    my ($self, $env) = @_;
#    my $resp = Plack::Response->new();
#
#    $self->response($resp);
#    $self->request($env);
#    $self->bootstrap;
#    $self->run;
#    $self->end;
#
#    return $self->response;
#}

##
## return the HTTP request object translated into something that
##  JavaScript can process
##
sub build_entrypoint_arguments {
  my $self = shift;

  my $cookies;
  if ( keys %{ $self->request->cookies } ) {
    for my $cookie_name ( keys %{ $self->request->cookies } ) {
      my $name  = $cookie_name;
      my $value = $self->request->cookies->{ $name };
        $cookies->{$name} = "$value";
    }
  }

  my $body  = $self->request->body_parameters;
  my $final_body = {};

  foreach my $key ($body->keys) {
    my @items = $body->get_all($key);
    if( scalar(@items) > 1){
        $final_body->{$key} = [
            map { decode_utf8($_) } @items
        ];
    } else {
        $final_body->{$key} = decode_utf8($items[0]);
    }
  }

  my %query = %{$self->request->query_parameters};

  my $request = {};
  my $uploads = {};
  eval {
    $request->{type}    = 'HTTP';
    $request->{uri}     = $self->request->request_uri;
    $request->{method}  = $self->request->method;
    $request->{query}   = \%query,
    $request->{body}    = $final_body,
    $request->{cookies} = $cookies;

    ## if we've got a multipart request, don't bother with
    ## the content.

    if ( keys %{ $self->request->uploads } ) {
      ## map the uploads to RSP file objects
        for my $name (keys %{ $self->request->uploads }){
            my $val = $self->request->uploads->{$name};
            $uploads->{$name} = RSP::JSObject::File->new($val->path, $val->basename);
        }
    } else {
      $request->{content} = decode_utf8($self->request->content);
    }

    $request->{headers} = {
			   map {
			     my $val = scalar( $self->request->headers->header( $_ ) );
			     ( $_ => $val )
			   } $self->request->headers->header_field_names
			  };

    $request->{queryString} = $self->request->uri->query;
  };

  $request->{uploads} = $uploads;

  return $request;
}

##
## this is mojo specific
##
#sub bw_consumed {
    #my $self = shift;
  #my $ib = $self->inbound_bw_consumed;
  #my $ob = $self->outbound_bw_consumed;
  #return $ib + $ob;
#}

#sub outbound_bw_consumed {
#  my $self = shift;
#  bytes::length( $self->response->build() );
#}

#sub inbound_bw_consumed {
#  my $self = shift;
#  bytes::length( $self->request->build() );
#}

1;
