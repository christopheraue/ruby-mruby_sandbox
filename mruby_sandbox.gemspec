# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mruby_sandbox/version'

Gem::Specification.new do |spec|
  spec.name          = "mruby_sandbox"
  spec.version       = MrubySandbox::VERSION
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["mail@christopheraue.net"]

  spec.summary       = %q{A mruby sandbox for ruby}
  spec.description   = %q{A mruby sandbox running in its own sub process and having only a single
                          pipe in and out to communicate with the outside. Provides a rather safe
                          environment to run untrusted code.}
  spec.homepage      = "https://github.com/christopheraue/ruby-mruby_sandbox"
  spec.license       = "MIT"
  spec.post_install_message = "Run `build_mruby_sandbox` to finish installation."

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = ["build_mruby_sandbox"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "pipe_rpc", "~> 0.1"
  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rspec", "~> 3.2.0"
  spec.add_development_dependency "rspec-its"
  spec.add_development_dependency "rspec-mocks-matchers-send_message", "~> 0.2"
end
