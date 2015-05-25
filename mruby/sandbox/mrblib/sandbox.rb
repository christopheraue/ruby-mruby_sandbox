class Sandbox < BasicObject
  def initialize
    clear
    @input = IO.new(0, 'r')  #STDIN
    @output = IO.new(1, 'w') #STDOUT
    @socket = PipeRpc::Socket.new(input: @input, output: @output)
    @server = PipeRpc::Server.new(socket: @socket, receiver: Controller.new(self))
    @clients = {}
    @server.listen #blocks and loops
  end

  def clear
    @untrusted = ::Untrusted.new(self)
    true
  end

  def eval(code)
    @untrusted.eval(code)
  end

  def add_receiver(args = {})
    @server.add_receiver(args)
  end

  def client_for(receiver)
    @clients[receiver] ||= PipeRpc::Client.new(socket: @socket, receiver: receiver)
  end
end

class Sandbox::Controller
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def clear
    @sandbox.clear
  end

  def eval(code)
    @sandbox.eval(code)
  end
end

class Untrusted
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def eval(code)
    instance_eval code
  end

  def export(args = {})
    @sandbox.add_receiver(args)
  end

  def client_for(receiver = :default)
    @sandbox.client_for(receiver)
  end
  alias_method :client, :client_for
end

# Remove constants from global namespace so untrusted code cannot mess around with it.
Sandbox::GC = Object.remove_const(:GC)
Sandbox::ObjectSpace = Object.remove_const(:ObjectSpace)
Sandbox::IO = Object.remove_const(:IO)
Sandbox::PipeRpc = Object.remove_const(:PipeRpc)
Object.remove_const(:Sandbox).new