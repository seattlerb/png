require 'hoe'

Hoe.new 'png', '1.1.0' do |s|
  s.summary = 'An almost-pure-ruby PNG library'
  s.description = 'png allows you to write a PNG file without installing any C libraries.  Also, stupid-simple PNG pie charts.'
  s.author = 'Ryan Davis'
  s.email = 'ryand-ruby@zenspider.com'
  s.rubyforge_name = 'seattlerb'

  p.changes = File.read('History.txt').scan(/\A(=.*?)^=/m).first.first

  s.extra_deps << ['RubyInline', '>= 3.5.0']
end

# vim: syntax=Ruby
