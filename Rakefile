$: << "../../RubyInline/dev/lib"
$: << "../../hoe/dev/lib"

require 'hoe'

Hoe.add_include_dirs "../../hoe/dev/lib" # HACK remove
Hoe.add_include_dirs "../../RubyInline/dev/lib", "lib"
Hoe.plugin :seattlerb
Hoe.plugin :inline

Hoe.spec 'png' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'
  developer 'Eric Hodel', 'drbrain@segment7.net'

  self.rubyforge_name = 'seattlerb'
end

# vim: syntax=Ruby
