
function main(aReq) {
    if(/^\/notfound/.test(aReq.uri)){
        return [404, [], "not found sorry"];
    } else if( /^\/returnfunc/.test(aReq.uri) ){
        return [200, [], function(){ return "returned from a function call!" }];
    } else if( /^\/headers/.test(aReq.uri) ){
        return [200, ['X-Foo', 'Bar'], "Blah"];
    } else if( /^\/cookie/.test(aReq.uri) ){
        var out = '';
        for(var x in aReq.cookies){
            out += x + ': '+aReq.cookies[x] + "\n";
        }
        return [200, [], out];
    } else if(/^\/jsobject$/.test(aReq.uri)){
        var filesystem = require('smart/filesystem');
        return [200, [], filesystem.get('blah.txt')]; 

    } else if(/^\/jsgenerator/.test(aReq.uri)){

        var things = [1, 2, 3];
        function foo(){
            while(things.length){
                var blah = things.shift();
                var tmp = blah + "\n";
                yield tmp;
            }
        };
        var gen = foo(); 

        return [200, [], gen];
    } else if(/^\/jsobject_notfile/.test(aReq.uri)){
        return [200, [], new Object({a: 1, b: 2, c: 3})];
    } else if(/^\/invalid/.test(aReq.uri)){
        return [200, [], {a: 1, b: 2, c: 3}];
    } else if(/^\/singlefunction/.test(aReq.uri)){
        var foobar = function(){ return "I am a combine harvester" };
        return foobar;
    } else if (/^\/basicpost/.test(aReq.uri)){
        var out = '' + aReq.method + ' ';
        for(x in aReq.body){
            //throw typeof aReq.body[x];
            if(typeof aReq.body[x] === 'object' && aReq.body[x].constructor === Array) {
                aReq.body[x].forEach(function(foo){ out += x + ',' + foo + ' '; });
            } else {
                out += x + ',' + aReq.body[x] + ' ';
            }
        }
        out += '.';
        return out;
    } else if (/^\/contentpost/.test(aReq.uri)){
        var out = '' + aReq.method + ' ';
        out += aReq.content;
        return out;
    } else if (/^\/upload/.test(aReq.uri)){
        var out = '' + aReq.method + "\n";
        for(x in aReq.uploads){
            var val = aReq.uploads[x];
            out += val.filename + ' - ' + val.mimetype + " - '" + val.contents + "'\n";
        }
        return out;
    } else {
        return "Hello";
    }
};

