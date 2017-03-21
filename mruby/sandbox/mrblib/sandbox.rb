class Sandbox < WorldObject::Connection
  self.world_class = 'InsideMrubySandbox'

  # logger.logger = ::Logger.new(STDERR)
  # logger.start

  class Ambassador
    world_public def inject(remote, opts = {})
      if opts[:as]
        config = opts[:as].to_s
        define_method = config.sub!('.', '#') ? :define_singleton_method : :define_method
        config = "Object##{config}" unless config.include? '#'
        owner, name = config.split('#')
        Object.const_get(owner).__send__(define_method, name) { remote }
      end

      remote
    end

    world_public def evaluate(code, file = '', lineno = 0)
      TOPLEVEL_BINDING.evaluate(code, nil, file, lineno)
    end
  end
end

TOPLEVEL_BINDING = self

# This is a tautology but otherwise constants defined during evaluation of
# the given string in Sandbox#evaluate are not defined under the root namespace
# but under Sandbox::WorldInterface.
def evaluate(*args)
  eval *args
end

Sandbox.new input: STDIN, output: STDOUT
WorldObject::EventLoop.global.start