$: << "../../RubyInline/dev/lib"

require 'hoe'
require './lib/png.rb'

Hoe.add_include_dirs("../../RubyInline/dev/lib",
                     "lib")

Hoe.new 'png', PNG::VERSION do |png|
  png.rubyforge_name = 'seattlerb'

  png.developer('Ryan Davis', 'ryand-ruby@zenspider.com')
  png.developer('Eric Hodel', 'drbrain@segment7.net')

  png.clean_globs << File.expand_path("~/.ruby_inline")
  png.extra_deps << ['RubyInline', '>= 3.5.0']
end

# vim: syntax=Ruby
