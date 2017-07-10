MRuby::Gem::Specification.new('mruby-sandbox') do |spec|
  spec.version     = '0.1.0'
  spec.summary     = "An mruby sandbox to run untrusted ruby code in a safe environment"
  spec.description = spec.summary

  spec.homepage    = 'https://github.com/christopheraue/ruby-mruby-sandbox'
  spec.license     = 'MIT'
  spec.authors     = ['Christopher Aue']

  spec.add_dependency 'mruby-world_object', '~> 0.9', github: 'christopheraue/m-ruby-world_object'
  spec.add_dependency 'mruby-io', github: 'iij/mruby-io', checksum_hash: '04774e5bf26b10150504635e68202a3965e2253b' # snapshot of iij/mruby_io for a controlled version
end
