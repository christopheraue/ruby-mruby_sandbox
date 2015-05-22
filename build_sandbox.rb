#!/usr/bin/env ruby

require 'fileutils'

repository = 'https://github.com/mruby/mruby.git'
dir = File.expand_path(File.dirname(__FILE__))
mruby_dir = File.expand_path('tmp/mruby')

Dir.mkdir 'tmp' unless File.exist?('tmp')
unless File.exist?(dir)
  system "git clone #{repository} #{dir}"
end

Dir.chdir mruby_dir
build_config = File.join(dir, 'build_config.rb')
build_args = ARGV
system "MRUBY_CONFIG=#{build_config} ./minirake #{build_args.join(' ')}"

Dir.chdir dir
Dir.mkdir 'bin' unless File.exist?('bin')
FileUtils.mv(File.join(mruby_dir, '/build/host/bin/mruby'), File.join(dir, '/bin/mruby-sandbox'))
FileUtils.mv(File.join(mruby_dir, '/build/irb/bin/mirb'), File.join(dir, '/bin/mirb'))
