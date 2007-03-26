require 'hoe'
require './lib/png.rb'

Hoe.new 'png', PNG::VERSION do |s|
  s.summary = 'An almost-pure-ruby PNG library'
  s.description = 'png allows you to write a PNG file without installing any C libraries.  Also, stupid-simple PNG pie charts.'
  s.author = 'Ryan Davis'
  s.email = 'ryand-ruby@zenspider.com'
  s.rubyforge_name = 'seattlerb'

  s.changes = s.paragraphs_of('History.txt', 0..1).join("\n\n")

  s.extra_deps << ['RubyInline', '>= 3.5.0']
end

# vim: syntax=Ruby
