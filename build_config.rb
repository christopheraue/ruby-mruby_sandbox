MRuby::Build.new do |conf|
  # Gets set by the VS command prompts.
  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
  end

  dir = File.expand_path(File.dirname(__FILE__))

  conf.gembox File.join(dir, 'mrbgems', 'safe-core')
  conf.gem core: 'mruby-bin-mirb' if ARGV.include? 'test'
  conf.gem "../mruby-restricted_io"
  conf.gem "../mruby-pipe_rpc"
  conf.gem dir if ARGV.empty?
end