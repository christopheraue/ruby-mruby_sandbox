class Sandbox < WorldObject::Gate
  world_class 'MRUBY'

  def initialize(toplevel_binding)
    super nil
    @toplevel_binding = toplevel_binding
  end

  def open(*)
    @keeper.message_pack.symbol_ext_type = 3
    super
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
    @toplevel_binding.eval(code, nil, file, lineno)
  end
end

# This is a tautology but otherwise constants defined during evaluation of
# the given string in Sandbox#evaluate are not defined under the root namespace
# but under Sandbox.
def eval(*args)
  super
end

Sandbox.new(self).tap do |sandbox|
  sandbox.open(input: IO.new(0, 'r'), output: IO.new(1, 'w'))
  sandbox.event_loop.start
end