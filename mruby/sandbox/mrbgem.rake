MRuby::Gem::Specification.new('mruby-sandbox') do |spec|
  spec.license = 'MIT'
  spec.version = '0.1.0'
  spec.summary = "A mruby sandbox whose job is to run untrusted ruby code in a safe environment"
  spec.authors = ['Christopher Aue']
  spec.homepage = 'https://github.com/christopheraue/ruby-mruby-sandbox'

  spec.add_dependency 'mruby-world_object', '~> 0.1', github: 'christopheraue/mruby-world_object'
  spec.add_dependency 'mruby-onig-regexp', '>= 0', github: 'mattn/mruby-onig-regexp'
end
