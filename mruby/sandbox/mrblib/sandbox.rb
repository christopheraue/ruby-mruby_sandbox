class Sandbox < WorldObject::Connection
  class WorldInterface < WorldObject::Connection::WorldInterface
    world_class 'MrubySandbox(mruby)'

    world_public def start_logging
      connection.logger.start ::Logger.new(STDERR)
    end

    world_public def stop_logging
      connection.logger.stop
    end

    world_public def inject(client, opts = {})
      if opts[:as]
        config = opts[:as].to_s
        define_method = config.sub!('.', '#') ? :define_singleton_method : :define_method
        config = "Object##{config}" unless config.include? '#'
        owner, name = config.split('#')
        Object.const_get(owner).__send__(define_method, name) { client }
      end

      client
    end

    world_public def evaluate(code, file = '', lineno = 0)
      TOPLEVEL_BINDING.evaluate(code, nil, file, lineno)
    end
  end
end

TOPLEVEL_BINDING = self

# This is a tautology but otherwise constants defined during evaluation of
# the given string in Sandbox#evaluate are not defined under the root namespace
# but under Sandbox.
def evaluate(*args)
  eval *args
end

Sandbox.new input: STDIN, output: STDOUT
WorldObject::EventLoop.global.start