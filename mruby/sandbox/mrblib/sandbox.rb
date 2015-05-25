class Sandbox
  def initialize
    clear
    @input = IO.new(0, 'r')  #STDIN
    @output = IO.new(1, 'w') #STDOUT
    @socket = PipeRpc::Socket.new(input: @input, output: @output)
    @server = PipeRpc::Server.new(socket: @socket, receiver: Controller.new(self))
    @clients = {}
    @server.listen #blocks and loops
  end

  attr_reader :untrusted

  def clear
    @untrusted = Untrusted.new
    @trusted = Trusted.new(self)
    true
  end

  def eval_untrusted(code)
    @untrusted.load(code)
  end

  def eval_trusted(code)
    @trusted.load(code)
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

  def eval_untrusted(code)
    @sandbox.eval_untrusted(code)
  end

  def eval_trusted(code)
    @sandbox.eval_trusted(code)
  end
end

class Sandbox::Trusted < Module
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def load(code)
    instance_eval code
  end

  def untrusted
    @sandbox.untrusted
  end

  def export(receiver, args = {})
    @sandbox.add_receiver(name: args.fetch(:as), receiver: receiver)
  end

  def client_for(receiver = :default)
    @sandbox.client_for(receiver)
  end
  alias_method :client, :client_for
end

class Untrusted < Module
  def load(code)
    instance_eval code
  end
end

# Remove constants from global namespace so untrusted code cannot mess around with it.
Sandbox::GC = Object.remove_const(:GC)
Sandbox::ObjectSpace = Object.remove_const(:ObjectSpace)
Sandbox::IO = Object.remove_const(:IO)
Sandbox::PipeRpc = Object.remove_const(:PipeRpc)
Object.remove_const(:Sandbox).new