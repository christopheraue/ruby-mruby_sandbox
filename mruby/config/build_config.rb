MRuby::Build.new do |conf|
  # Gets set by the VS command prompts.
  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
  end

  dir = File.expand_path(File.dirname(__FILE__))
  root_dir = File.expand_path('..', dir)
  sandbox_mrbgem = File.join(root_dir, 'sandbox')

  conf.gembox File.join(dir, 'safe-core')
  conf.gem core: 'mruby-bin-mirb' if ENV['TEST']
  conf.gem File.join(root_dir, '../../mruby-pipe_rpc')
  conf.gem sandbox_mrbgem unless ENV['TEST']
end