var require;
(function(){

    var local_extensions = extensions;

    var module = {};
    require = function(module_name, stack){
        if(!stack) stack = [];
        var self = arguments.callee;
 
        var resolved = resolve(module_name, stack);
        var [use_string, breakup] = [resolved.identifier, resolved.breakup];
 
        if(self.moduleCache[use_string]) return self.moduleCache[use_string].exports;
        self.moduleCache[use_string] = { id: use_string, exports: {} };

        // NATIVE
        if( /^smart/.test(use_string) ){
            // Now we need to examine the contents for local_extensions
            var deeply = breakup.slice(1);
            var top_level = local_extensions; 
            for(var x in local_extensions){
                if( deeply[0] in local_extensions[ x ]){
                    top_level = local_extensions[ x ][ deeply[0] ];
                    deeply.shift();
                }
            }

            while(deeply.length){
                if(deeply[0] in top_level){
                    top_level = top_level[ deeply[0] ];
                } else {
                    throw new Error("Unable to load native smart module: "+module_name);
                }
                deeply.shift();
            }

            self.moduleCache[use_string].exports = top_level;
            return self.moduleCache[use_string].exports;
        }

        if(breakup.length > 1){
            try {
                system.filesystem.get(self.path + use_string + ".js");
            } catch (e) {
                // If relative file doesn't exist, fall back to absolute
                var resolved_again = resolve(breakup[breakup.length -1], stack);
                [use_string, breakup] = [resolved_again.identifier, resolved_again.breakup];
            }
        }
 
        var new_require = function(new_module_name){
            return require(new_module_name, stack.concat( breakup.slice(0, -1) ));
        };
 
        var func = load(use_string);
        func.apply(func, [new_require, module, self.moduleCache[use_string].exports]);
      
        return self.moduleCache[use_string].exports;
    };
    require.moduleCache = {};
    require.path = '';
 
    var resolve = function(module_name, stack) {
        var breakup = module_name.split('/');
 
        switch(breakup[0]){
            case '.':
                breakup.shift(); break;
            case '..':
                if(stack.length == 0) throw new Error("Unable to load module '"+module_name+"', already at top level");
                stack.pop(); breakup.shift(); break;
            default:
                stack = []; break;
        }         
        
        var [current_directory, relative_file] = [stack.join('/'), breakup.join('/')];
        var use_string = current_directory ? (current_directory + '/' + relative_file) : relative_file;
        return { 'identifier': use_string, 'breakup': breakup };
    };
 
    var load = function(use_string){
        var load_this = require.path + use_string + '.js';
        var func = new Function(["require", "module", "exports"], require('smart/filesystem').get(load_this).contents);
        return func;
    };
})();

