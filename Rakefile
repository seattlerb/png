require 'rubygems'
require 'rake'

$VERBOSE = nil

$spec = Gem::Specification.new do |s|
  s.name = 'png'
  s.version = '1.1.0'
  s.summary = 'An almost-pure-ruby PNG library'
  s.description = 'png allows you to write a PNG file without installing any C libraries.'
  s.author = 'Ryan Davis'
  s.email = 'ryand-ruby@zenspider.com'

  s.has_rdoc = true
  s.files = File.read('Manifest.txt').split($/)
  s.require_path = 'lib'

  s.add_dependency 'RubyInline', '>= 3.5.0'
end

require '../../tasks/project_defaults'

# vim: syntax=Ruby
