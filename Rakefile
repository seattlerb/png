$: << "../../RubyInline/dev/lib"
$: << "../../hoe/dev/lib"

require "hoe"

Hoe.add_include_dirs("../../RubyInline/dev/lib",
                     "../../ZenTest/dev/lib",
                     "lib")

Hoe.plugin :seattlerb
Hoe.plugin :inline

Hoe.spec "png" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
end

# vim: syntax=Ruby
