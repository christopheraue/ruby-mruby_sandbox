class Sandbox < WorldObject::Connection
  def logger
    @logger ||= ::Logger.new(STDERR)
  end

  interface do
    world_class 'MrubySandbox'

    world_public def start_logging
      @connection.interaction_logger.start
    end

    world_public def stop_logging
      @connection.interaction_logger.stop
    end

    world_public def inject(client, opts = {})
      if opts[:as]
        config = opts[:as].to_s
        define_method = config.sub!('.', '#') ? :define_singleton_method : :define_method
        config = "Kernel##{config}" unless config.include? '#'
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

socket = { input: STDIN, output: STDOUT }
WorldObject.global.connect_to(socket, as: Sandbox)
WorldObject.global.serve