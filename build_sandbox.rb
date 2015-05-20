#!/usr/bin/env ruby

repository, dir = 'https://github.com/mruby/mruby.git', 'tmp/mruby'
build_args = ARGV

Dir.mkdir 'tmp'  unless File.exist?('tmp')
unless File.exist?(dir)
  system "git clone #{repository} #{dir}"
end

system %Q[cd #{dir}; MRUBY_CONFIG=#{File.join(File.expand_path(File.dirname(__FILE__)), 'build_config.rb')} ruby minirake #{build_args.join(' ')}]
system "mv #{dir}/build/host/bin/mruby ./mruby-sandbox"
