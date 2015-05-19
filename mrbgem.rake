MRuby::Gem::Specification.new('mruby-sandbox') do |spec|
  spec.license = 'MIT'
  spec.version = '0.1.0'
  spec.summary = "A mruby sandbox that can communicate with the outside through a set of pipes"
  spec.description = <<DESC
The sandbox's job is to run untrusted ruby code in a safe environment. mruby's
core does not really offer access to system critical operations while still
supporting ruby's core features. This makes it a good basis for a sandbox.
The sandbox runs as a subprocess of a managing parent process. To be able to
communicate with its parent the sandbox also loads a restricted implementation
of the IO library that only allows reading and writing to io endpoints the
parent passed down to the sandbox. The IO library does not implement any
operations creating new endpoints, accessing files on the system or the like.
The communication between the sandbox and its parent uses an rpc mechanism.
Both sides can offer a server, so that the sand can call approved methods
of the parent and vice versa.
DESC
  spec.authors = ['Christopher Aue']
  spec.homepage = 'https://github.com/christopheraue/mruby-sandbox'

  spec.add_dependency 'mruby-local_io', '~> 0.1'
  spec.add_dependency 'mruby-local_rpc', '~> 0.1'
end
