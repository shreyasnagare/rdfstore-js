#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'json'

NODEUNIT = "/Users/antonio/Development/Projects/js/rdfstore-js/node_modules/nodeunit/bin/nodeunit"

def load_configuration
  puts "*** loading configuration"
  require(File.dirname(__FILE__)+"/configuration")
end

def build_distribution_directory(system);
  begin
    puts "*** building distribution directory"
    Dir.mkdir "./dist"
    Dir.mkdir "./dist/browser"
    Dir.mkdir "./dist/browser_persistent"    
    Dir.mkdir "./dist/nodejs"
  rescue 
    puts "(!) dist directory already exits"
    FileUtils.rm_r("./dist/browser/") if system == 'browser'
    FileUtils.rm_r("./dist/browser_persistent/")  if system == 'browser_persistent'    
    FileUtils.rm_r("./dist/nodejs/")  if system == 'nodejs'
    Dir.mkdir "./dist/browser"            if system == 'browser'
    Dir.mkdir "./dist/browser_persistent" if system == 'browser_persistent'    
    Dir.mkdir "./dist/nodejs"             if system == 'nodejs'
  end
end

def minimize_output_browser_yui
  puts "*** minimizing output"
  `cp ./yuicompressor-2.4.6.jar ./dist/browser/`
  `cd ./dist/browser && java -jar yuicompressor-2.4.6.jar rdf_store.js > rdf_store_min.js`
  `cp ./dist/browser/rdf_store_min.js ./dist/browser/rdf_store_min.js.bak`  
  `cd ./dist/browser && gzip -9 rdf_store_min.js`
  `mv ./dist/browser/rdf_store_min.js.bak ./dist/browser/rdf_store_min.js`
  `rm ./dist/browser/yuicompressor-2.4.6.jar`
end

def minimize_output_browser
  puts "*** minimizing output"
  `cp ./closure-compiler.jar ./dist/browser/`
#  `cd ./dist/browser && java -jar closure-compiler.jar --compilation_level=ADVANCED_OPTIMIZATIONS --js=rdf_store.js > rdf_store_min.js`
  `cd ./dist/browser && java -jar closure-compiler.jar --compilation_level=SIMPLE_OPTIMIZATIONS --js=rdf_store.js > rdf_store_min.js`
  `cp ./dist/browser/rdf_store_min.js ./dist/browser/rdf_store_min.js.bak`
  `cd ./dist/browser && gzip -9 rdf_store_min.js`
  `mv ./dist/browser/rdf_store_min.js.bak ./dist/browser/rdf_store_min.js`
  `rm ./dist/browser/closure-compiler.jar`
  `cp ./dist/browser/rdf_store*.js ./browsertests/non_persistent/`
  `cp ./dist/browser/rdf_store*.js ./browsertests/workers/resources/public/`
end

def minimize_output_browser_persistent
  puts "*** minimizing output"
  `cp ./closure-compiler.jar ./dist/browser_persistent/`
#  `cd ./dist/browser && java -jar closure-compiler.jar --compilation_level=ADVANCED_OPTIMIZATIONS --js=rdf_store.js > rdf_store_min.js`
  `cd ./dist/browser_persistent && java -jar closure-compiler.jar --compilation_level=SIMPLE_OPTIMIZATIONS --js=rdf_store.js > rdf_store_min.js`
  `cp ./dist/browser_persistent/rdf_store_min.js ./dist/browser_persistent/rdf_store_min.js.bak`
  `cd ./dist/browser_persistent && gzip -9 rdf_store_min.js`
  `mv ./dist/browser_persistent/rdf_store_min.js.bak ./dist/browser_persistent/rdf_store_min.js`
  `rm ./dist/browser_persistent/closure-compiler.jar`
  `cp ./dist/browser_persistent/rdf_store*.js ./browsertests/persistent/`
end

def minimize_output_nodejs
  puts "*** minimizing output"
  `cp ./closure-compiler.jar ./dist/nodejs/`
  `cd ./dist/nodejs && java -jar closure-compiler.jar --compilation_level=SIMPLE_OPTIMIZATIONS --js=index.js > rdf_store_min.js`
  `cp ./dist/nodejs/rdf_store_min.js ./dist/nodejs/rdf_store_min.js.bak`  
  `cd ./dist/nodejs && gzip -9 rdf_store_min.js`
  `mv ./dist/nodejs/rdf_store_min.js.bak ./dist/nodejs/rdf_store_min.js`
  `rm ./dist/nodejs/closure-compiler.jar`
end

def write_nodejs_preamble(of)
  js_code =<<__END
(function() {\r\n
__END
  of << js_code
end


def write_nodejs_coda(of)
  js_code =<<__END
try{
  module.exports = Store;
}catch(e){}
})();
__END

  of << js_code;
end

def write_test_min_preamble(of)
  js_code =<<__END
var Store = require('./rdf_store_min.js');

console.log(Store);

var Lexicon = {};
Lexicon.Lexicon = function(f) {
    Store.create(function(store) {
        store.execute = function() {
            if(arguments.length === 2) {
                this.engine.execute(arguments[0],
                                    arguments[1]);
            } else if(arguments.length === 4) {
                this.engine.execute(arguments[0],
                                    arguments[1],
                                    arguments[2],
                                    arguments[3]);
            }
        };
        f(store);
    });
};

var QuadBackend = {};
QuadBackend.QuadBackend = function(opts,f) {
    f(opts);
};

var QueryEngine = {};
QueryEngine.QueryEngine = function(opts) {
    return opts.lexicon;
};
__END

  of << js_code;
end

def process_files_for_test_min
  File.open("./dist/nodejs/test_min.js", "w") do |of|
    
    write_test_min_preamble(of)
    
    File.open("./src/js-query-engine/test/test_cases.js", "r") do |f|
      puts "*** Adding W3C test cases to test file"
      f.each_line do |line|
        if(line =~ /[a-zA-Z0-9 =]*require/) == 0
          puts " * ignoring require"
        else
          of << line
        end
      end
    end
  end
end

def process_file_for_nodejs(of, f) 
  f.each_line do |line|
    if (line =~ /exports\.[a-zA-Z]+ *= *\{ *\};/) == 0
      puts " * modifying: #{line} -> #{line.split("exports.")[1]}"
      of << ("var "+line.split("exports.")[1])
    elsif (line =~ /var *([a-zA-Z]+) *= *exports\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(__dirname\+['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var BaseTree *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\./) == 0
      puts " * writing right MemoryTree"
      tree = line.split(".")[-1];
      of << "var BaseTree = #{tree}"
    else
      # require for YUI compressor
      line.gsub!('dataset.default', "dataset['default']")
      line.gsub!("default:[]","'default':[]")
      line.gsub!(".while","meanwhile");
      line.gsub!("Callbacks.deleted","____TMP_DOT_DELETE____");
      line.gsub!(".delete","['delete']");
      line.gsub!("____TMP_DOT_DELETE____","Callbacks.deleted");
      line.gsub!(".extends","['extends']");
      line.gsub!(".with","['with']");
      line.gsub!(".using","['using']");
      of << line
    end
  end
end

def process_files_for_nodejs
  File.open("./dist/nodejs/index.js", "w") do |of|
    
    write_nodejs_preamble(of)
    
    BUILD_CONFIGURATION[:nodejs][:modules].each do |module_file|
      puts "*** processing #{module_file}"
      File.open(module_file, "r") do |f|
        process_file_for_nodejs(of, f)
        of << "\r\n// end of #{module_file} \r\n"
      end
    end

  
    File.open("./src/js-communication/src/tcp_transport.js", "r") do |f|
      puts "*** processing TCP Transport file"
      process_file_for_nodejs(of, f)
    end
  
    write_nodejs_coda(of)
  end
end

def make_package_json
  puts "*** generating package.json"
  package_config = BUILD_CONFIGURATION[:nodejs][:package].to_json
  File.open("./dist/nodejs/package.json", 'w') do |of|
    of << package_config
  end
end

def npm_linking
  exec 'cd ./dist/nodejs && npm link'
end

def make_nodejs
  puts "  NODEJS CONFIGURATION"
  load_configuration
  build_distribution_directory 'nodejs'
  process_files_for_nodejs
  make_package_json
  #npm_linking
  puts "\r\n*** FINISHED";
end


def write_browser_preamble(of)
  js_code =<<__END
(function() {\r\n

try {
  console = console || {};
} catch(e) {
  console = {};
  console.log = function(e){};
}
__END
  of << js_code
end

def process_file_for_browser(of, f) 
  f.each_line do |line|
    if (line =~ /exports\.[a-zA-Z]+ *= *\{ *\};/) == 0
      puts " * modifying: #{line} -> var #{line.split("exports.")[1]}"
      of << "var #{line.split('exports.')[1]}"
    elsif (line =~ /var *([a-zA-Z]+) *= *exports\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(__dirname\+['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(['\"]webworker[\"']\);/)
      puts " * ignoring require for NodeJS WebWorkers: #{line}"  
    elsif (line =~ /var BaseTree *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\./) == 0
      puts " * writing right MemoryTree"
      tree = line.split(".")[-1];
      of << "var BaseTree = #{tree}"
    else
      # require for YUI compressor
      line.gsub!('dataset.default', "dataset['default']")
      line.gsub!("default:[]","'default':[]")
      line.gsub!(".while","meanwhile");
      line.gsub!("Callbacks.deleted","____TMP_DOT_DELETE____");
      line.gsub!(".delete","['delete']");
      line.gsub!("____TMP_DOT_DELETE____","Callbacks.deleted");
      line.gsub!(".extends","['extends']");
      line.gsub!(".with","['with']");
      line.gsub!(".using","['using']");
      of << line
    end
  end
end

def process_file_for_browser_persistent(of, f) 
  f.each_line do |line|
    if (line =~ /exports\.[a-zA-Z]+ *= *\{ *\};/) == 0
      puts " * modifying: #{line} -> var #{line.split("exports.")[1]}"
      of << "var #{line.split('exports.')[1]}"
    elsif (line =~ /var BaseTree *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\./) == 0
      puts " * writing Persistent Memory Tree"
      of << "var BaseTree = WebLocalStorageBTree;"
    elsif (line =~ /var Lexicon *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\./) == 0
      puts " * writing Persistent Lexicon"
      of << "var Lexicon = WebLocalStorageLexicon;"
    elsif (line =~ /var *([a-zA-Z]+) *= *exports\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(__dirname\+['\"]{1,1}[a-zA-Z_\.\/-]*['\"]{1,1}\)\.\1;/) == 0
      puts " * ignoring: #{line}"
    elsif (line =~ /var *([a-zA-Z]+) *= *require\(['\"]webworker[\"']\);/)
      puts " * ignoring require for NodeJS WebWorkers: #{line}"  
    else
      # require for YUI compressor
      line.gsub!('dataset.default', "dataset['default']")
      line.gsub!("default:[]","'default':[]")
      line.gsub!(".while","meanwhile");
      line.gsub!("Callbacks.deleted","____TMP_DOT_DELETE____");
      line.gsub!(".delete","['delete']");
      line.gsub!("____TMP_DOT_DELETE____","Callbacks.deleted");
      line.gsub!(".extends","['extends']");
      line.gsub!(".with","['with']");
      line.gsub!(".using","['using']");
      of << line
    end
  end
end

def write_browser_coda(of)
  js_code =<<__END
try {
  window.rdfstore = Store;
} catch(e) { }
})();
__END

  of << js_code;
end

def process_files_for_browser
  File.open("./dist/browser/rdf_store.js", "w") do |of|
    
    if BUILD_CONFIGURATION[:browser][:load_jquery]
      File.open("./src/js-communication/src/jquery_ajax.js", "r") do |f|
        f.each_line do |line|
          of << line
        end
      end
    end

    
    write_browser_preamble(of)
    
    BUILD_CONFIGURATION[:browser][:modules].each do |module_file|
      puts "*** processing #{module_file}"
      File.open(module_file, "r") do |f|
        process_file_for_browser(of, f)
        of << "\r\n// end of #{module_file} \r\n"
      end
    end

    write_browser_coda(of)
  end
end

def process_files_for_browser_persistent
  File.open("./dist/browser_persistent/rdf_store.js", "w") do |of|

    if BUILD_CONFIGURATION[:browser_persistent][:load_jquery]
      File.open("./src/js-communication/src/jquery_ajax.js", "r") do |f|
        f.each_line do |line|
          of << line
        end
      end
    end

    
    write_browser_preamble(of)
    
    BUILD_CONFIGURATION[:browser_persistent][:modules].each do |module_file|
      puts "*** processing #{module_file}"
      File.open(module_file, "r") do |f|
        process_file_for_browser_persistent(of, f)
        of << "\r\n// end of #{module_file} \r\n"
      end
    end

    write_browser_coda(of)
  end
end

def make_browser
  puts "  BROWSER CONFIGURATION"
  load_configuration
  build_distribution_directory 'browser'
  process_files_for_browser
  minimize_output_browser
  puts "\r\n*** FINISHED";
end

def make_browser_persistent
  puts "  BROWSER PERSISTENT CONFIGURATION"
  load_configuration
  build_distribution_directory 'browser_persistent'
  process_files_for_browser_persistent
  minimize_output_browser_persistent
  puts "\r\n*** FINISHED";
end

def test_minimized
  puts "  MINIMIZED NODEJS CONFIGURATION"
  load_configuration
  build_distribution_directory 'nodejs'
  process_files_for_nodejs
  process_files_for_test_min
  minimize_output_nodejs
  puts `cd ./dist/nodejs && #{NODEUNIT} ./test_min.js`
  puts "\r\n*** FINISHED";
end


if ARGV.length != 1
  puts "USAGE make.rb [nodejs | browser | browser_persistent | tests | test_min]"
else
  if ARGV[0] == "nodejs"
    make_nodejs
  elsif ARGV[0] == "browser"
    make_browser
  elsif ARGV[0] == "browser_persistent"
    make_browser_persistent
  elsif ARGV[0] == "test_min"
    test_minimized
  elsif ARGV[0] == "tests"
    exec "#{NODEUNIT} ./src/js-trees/tests/* ./src/js-store/test/* ./src/js-sparql-parser/test/* ./src/js-rdf-persistence/test/* ./src/js-query-engine/test/* ./src/js-communication/test/* ./src/js-connection/tests/*"
  else
    puts "Unknown configuration: #{ARGV[0]}"
    puts "USAGE make.rb [nodejs | browser | browser_persistent | tests | test_min]"
  end
end
