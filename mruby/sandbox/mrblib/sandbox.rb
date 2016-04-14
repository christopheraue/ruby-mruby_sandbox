class Sandbox < PipeRpc::Gateway
  def initialize
    input = IO.new(0, 'r')  #STDIN
    output = IO.new(1, 'w') #STDOUT
    super(input: input, output: output)
  end

  def set_up(main)
    servers.add(default: main)

    sandbox = self

    main.define_singleton_method :add_server do |*args|
      sandbox.servers.add(*args)
    end

    main.define_singleton_method :client_for do |server|
      sandbox.clients[server]
    end

    loop do
      handle_message # blocks every iteration
    end
  end
end

# Interface for untrusted code to communicate with the outside
class << self
  def eval(code, file = '', lineno = 0)
    instance_eval(code, file, lineno)
  end

  def client
    clients[:default]
  end
end

# Remove constants from global namespace so untrusted code cannot mess around with it.
Object.remove_const(:GC)
Object.remove_const(:ObjectSpace)
Sandbox::IO = Object.remove_const(:IO)
Sandbox::PipeRpc = Object.remove_const(:PipeRpc)
Object.remove_const(:Sandbox).new.set_up(self)