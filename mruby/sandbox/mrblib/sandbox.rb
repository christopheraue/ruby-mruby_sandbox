class Sandbox < WorldObject::Connection
  def initialize(socket, toplevel_binding)
    super socket
    @toplevel_binding = toplevel_binding
  end

  attr_reader :toplevel_binding

  def log(severity, message)
    IO.new(2, 'w').puts "#{severity} #{message}"
  end
end

class Sandbox::Interface < WorldObject::Connection::Interface
  world_class 'MrubySandbox'

  world_public def start_logging
    @connection.logger.start
  end

  world_public def stop_logging
    @connection.logger.stop
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
    @connection.toplevel_binding.eval(code, nil, file, lineno)
  end
end

# This is a tautology but otherwise constants defined during evaluation of
# the given string in Sandbox#evaluate are not defined under the root namespace
# but under Sandbox.
def eval(*args)
  super
end

socket = WorldObject::StreamSocket.new(input: IO.new(0, 'r'), output: IO.new(1, 'w'))
sandbox = Sandbox.new(socket, self)
sandbox.event_loop.start