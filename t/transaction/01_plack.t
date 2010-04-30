#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 30_000;

use Plack::Test;
use HTTP::Request;

use RSP::Config;
use RSP;

$RSP::CONFIG = RSP::Config->new(config => { 
    '_' => {
        root => './t/transaction/fakeroot/',
        available_extensions => 'Import,FileSystem,HTTP',
        extensions => 'Import,FileSystem,HTTP',
    },
    rsp => { hostroot => 'sites' },
});
RSP->new;

Basic: {
    use_ok('RSP::Transaction::Plack');

    my $app = RSP::Transaction::Plack->app;
    test_psgi $app, sub {
        my $cb = shift;

        # XXX - See t/transaction/fakeroot/sites/basic/bootstrap.js
        OK: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = HTTP::Request->new(GET => 'http://basic/');
            my $res = $cb->($req);
            is $res->code, 200, "OK: status code correct";
            is $res->content, "Hello", "OK: content is correct";
            is $res->header('Content-Length'), 5, "OK: content length is correct";
        }
        NOTFOUND: {
            my $req = HTTP::Request->new(GET => 'http://basic/notfound');
            my $res = $cb->($req);
            is $res->code, 404, "NOTFOUND: status code correct";
            is $res->content, "not found sorry", "NOTFOUND: content is correct";
        }
        HEADERS: {
            my $req = HTTP::Request->new(GET => 'http://basic/headers');
            my $res = $cb->($req);
            is $res->code, 200, 'HEADERS: status code is correct';
            is $res->content, 'Blah', 'HEADERS: content is correct';
            is $res->header('X-Foo'), 'Bar', 'HEADERS: header is correct';
        }

    };
}

Body_Types: {
    my $app = RSP::Transaction::Plack->app;
    test_psgi $app, sub {
        my $cb = shift;

        # XXX - See t/transaction/fakeroot/sites/basic/bootstrap.js
        JavaScript_Function: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = HTTP::Request->new(GET => 'http://basic/returnfunc');
            my $res = $cb->($req);
            is $res->code, 200, "Function: status code correct";
            is $res->content, "returned from a function call!", "Function: content is correct";
            is $res->header('Content-Length'), 30, "Function: content length is correct";
        }

        JavaScript_Function_not_array: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = HTTP::Request->new(GET => 'http://basic/singlefunction');
            my $res = $cb->($req);
            is $res->code, 200, "Function not array: status code correct";
            is $res->content, "I am a combine harvester", "Function not array: content is correct";
            is $res->header('Content-Length'), 24, "Function not array: content length is correct";
        }

        JSObject: {
            my $req = HTTP::Request->new(GET => 'http://basic/jsobject');
            my $res = $cb->($req);
            is $res->code, 200, "JSObject: status code correct";
            is $res->content, "hello\n", "JSObject: content is correct";
            is $res->header('Content-Length'), 6, "JSObject: content length is correct";
        }

        #JSObject_notfile: {
        #    my $req = HTTP::Request->new(GET => 'http://basic/jsobject_notfile');
        #    my $res = $cb->($req);
        #    is $res->code, 200, "JSObject not file: status code correct";
        #    is $res->content, "hello\n", "JSObject not file: content is correct";
        #}

        JavaScript_Generator: {
            my $req = HTTP::Request->new(GET => 'http://basic/jsgenerator');
            my $res = $cb->($req);
            is $res->code, 200, "Generator: status code correct";
            is $res->content, "1\n2\n3\n", "Generator: content is correct";
            # chunked... so no Content-Length
            is $res->header('Content-Length'), undef, "Generator: content length is correct";
        }
        Failures: {
            my $req = HTTP::Request->new(GET => 'http://basic/invalid');
            my $res = $cb->($req);
            is $res->code, 500, "Failure: status code correct";
            is $res->content, "Invalid response body type\n", "Failure: content is correct";
        }
    };

}

Cookies: {
    my $app = RSP::Transaction::Plack->app;
    test_psgi $app, sub {
        my $cb = shift;

        # XXX - See t/transaction/fakeroot/sites/basic/bootstrap.js
        # XXX XXX - this probably needs to be updated to take care of sorting
        basic: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = HTTP::Request->new(GET => 'http://basic/cookie');
            $req->header(Cookie => 'hello=bob; foo=bar');
            my $res = $cb->($req);
            is $res->code, 200, "Cookies: status code correct";
            is $res->content, "hello: bob\nfoo: bar\n", "Cookies: content is correct";
        }

    };

}

use HTTP::Request::Common;
Body_parameters: {
    my $app = RSP::Transaction::Plack->app;
    test_psgi $app, sub {
        my $cb = shift;

        # XXX - See t/transaction/fakeroot/sites/basic/bootstrap.js
        POST: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = POST('http://basic/basicpost', [a => 1, b => 2]);
            my $res = $cb->($req);
            is $res->code, 200, "POST: status code correct";
            is $res->content, "POST a,1 b,2 .", "POST multivalue: content is correct";
        }
        POST_multivalue: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = POST('http://basic/basicpost', [a => 1, b => 2, a => 3]);
            my $res = $cb->($req);
            is $res->code, 200, "POST multivalue: status code correct";
            is $res->content, "POST a,1 a,3 b,2 .", "POST multivalue: content is correct";
        }
        POST_content: {
            # This test uses just a plain string return from JS space rather than an array
            my $req = POST('http://basic/contentpost', Content => "moo");
            my $res = $cb->($req);
            is $res->code, 200, "POST content: status code correct";
            is $res->content, "POST moo", "POST content: content is correct";
        }
        POST_upload: {
            my $req = POST('http://basic/upload', 'Content-Type' => 'form-data', Content => [
                1 => [ undef, 'alpha.txt', 'Content-Type' => 'text/plain', Content => "one" ],
                2 => [ undef, 'beta.js', 'Content-Type' => 'application/javascript', Content => "two" ],
            ]);
            my $res = $cb->($req);
            is $res->code, 200, "POST upload: status code correct";
            is $res->content, "POST\nalpha.txt - text/plain - 'one'\nbeta.js - application/javascript - 'two'\n", "POST upload: content is correct";        
        }
    };


}
