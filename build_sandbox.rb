#!/usr/bin/env ruby

require 'fileutils'

def test?
  ARGV.include? 'test'
end

def clean?
  ARGV.include? 'clean'
end

def build?
  not test? and not clean?
end

repository = 'https://github.com/mruby/mruby.git'
dir = File.expand_path(File.dirname(__FILE__))
mruby_dir = File.expand_path('tmp/mruby')

Dir.mkdir 'tmp' unless File.exist?('tmp')
unless File.exist?(mruby_dir)
  system "git clone #{repository} #{mruby_dir}"
end

Dir.chdir mruby_dir
build_config = File.join(dir, 'build_config.rb')
build_args = ARGV
system "#{test? ? 'TEST=test' : ''} MRUBY_CONFIG=#{build_config} ./minirake #{build_args.join(' ')}"


Dir.chdir dir
Dir.mkdir 'bin' unless File.exist?('bin')
FileUtils.cp File.join(mruby_dir, '/build/host/bin/mruby'), File.join(dir, '/bin/mruby-sandbox') if build?
FileUtils.cp File.join(mruby_dir, '/build/host/bin/mirb'), File.join(dir, '/bin/mirb') if test?
