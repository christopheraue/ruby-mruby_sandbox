class Sandbox < WorldObject::Gate
  world_class 'MRUBY'

  def initialize(toplevel_binding)
    super nil, input: IO.new(0, 'r'), output: IO.new(1, 'w')
    @toplevel_binding = toplevel_binding
    self.ruby_symbol_ext_type = 3
  end

  world_public def inject(client, opts = {})
    if opts[:as]
      config = opts[:as].to_s
      define_method = config.sub!('.', '#') ? :define_singleton_method : :define_method
      config = "Kernel##{config}" unless config.include? '#'
      owner, name = config.split('#')
      Object.const_get(owner).__send__(define_method, name) { client }
    else
      client
    end
  end

  world_public def eval(code, file = '', lineno = 0)
    @toplevel_binding.eval(code, nil, file, lineno)
  end
end

Sandbox.new(self).tap do |sandbox|
  sandbox.open
  loop{ sandbox.handle_message } # blocks every iteration
end