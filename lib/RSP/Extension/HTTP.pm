package RSP::Extension::HTTP;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Encode;
use HTTP::Request;
use LWP::UserAgent;

use Try::Tiny;

our $VERSION = '1.00';

sub bind {
    my ($self) = @_;

    $self->bind_extension({
        http => {
            request => $self->generate_js_closure('http_request'),
            get => $self->generate_js_closure('get'),
        },
    });
}

## why does LWPx::ParanoidAgent need this?
{
    no warnings 'redefine';
    sub LWP::Debug::debug { }
    sub LWP::Debug::trace { }
}

sub http_request {
    my ($self, @js_args) = @_;

    my $ua = _get_ua();
    my $response = try {
        my @args;
        for my $part (@js_args){
            push(@args, (
                ref($part) ? $part : Encode::encode("utf8", $part)
            ));
        }

        my $req = shift @args;
        my $r = ref($req) ? HTTP::Request->new(@$req) : HTTP::Request->new($req, @args);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub _get_ua {
    my $ua = LWP::UserAgent->new;
    $ua->agent("Joyent Smart Platform / HTTP / $VERSION");
    $ua->timeout( 60 );
    return $ua;
}

sub _convert_headers {
    my ($headers) = @_;
    my $tmp = [];
    if(ref($headers) eq 'HASH'){
        for my $k (keys %$headers){
            my $val = $headers->{$k};
            if(ref($val) eq 'ARRAY'){
                for my $v (@$val){
                    push(@$tmp, $k, $v);
                }
            } else {
                push(@$tmp, $k, $val);
            }
        }
    } elsif(ref($headers) eq 'ARRAY'){
        $tmp = $headers;
    } else {
        die "Headers must be either and array of key value pairs or an object literal";
    }

    return $tmp;
}

sub get {
    my ($self, $uri, $headers) = @_;

    my $ua = _get_ua();
    $headers = _convert_headers($headers);

    my $response = try {
        my $r = HTTP::Request->new(GET => $uri, $headers);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub head {
    my ($self, $uri, $headers) = @_;

    my $ua = _get_ua();
    $headers = _convert_headers($headers);

    my $response = try {
        my $r = HTTP::Request->new(HEAD => $uri, $headers);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub delete {
    my ($self, $uri, $headers) = @_;

    my $ua = _get_ua();
    $headers = _convert_headers($headers);

    my $response = try {
        my $r = HTTP::Request->new(DELETE => $uri, $headers);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub put {
    my ($self, $uri, $headers, $content) = @_;

    my $ua = _get_ua();
    $headers = _convert_headers($headers);

    my $response = try {
        my $r = HTTP::Request->new(PUT => $uri, $headers, $content);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub post {
    my ($self, $uri, $headers, $content) = @_;

    my $ua = _get_ua();
    $headers = _convert_headers($headers);

    my $response = try {
        my $r = HTTP::Request->new(POST => $uri, $headers, $content);
        $ua->request( $r );
    } catch { 
        die "Could not complete HTTP Request: $_";
    };

    my $ro = $self->response_to_object($response);
    return $ro;
}

sub response_to_object {
  my $class = shift;
  my $response = shift;
  my %headers = %{ $response->{_headers} };
  my $ro = {
	    'headers' => \%headers,
	    'content' => $response->decoded_content,
	    'code'    => $response->code,
	   };
  return $ro;
}

__PACKAGE__->meta->make_immutable;
1;
