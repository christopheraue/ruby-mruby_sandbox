class Sandbox
  # Remove constants from global namespace so no one can mess around with it.
  IO = Object.remove_const :IO
  PipeRpc = Object.remove_const :PipeRpc

  def initialize
    clear
    @input = IO.new(0, 'r')  #STDIN
    @output = IO.new(1, 'w') #STDOUT
    @socket = PipeRpc::Socket.new(input: @input, output: @output)
    @server = PipeRpc::Server.new(socket: @socket, receiver: Controller.new(self))
    @clients = {}
    @output.puts @input.gets.bytes.join(', ')
    @server.listen #blocks and loops
  end

  attr_reader :untrusted

  def clear
    @untrusted = Untrusted.new
    @trusted = Trusted.new(self)
    true
  end

  def load_untrusted(code)
    @untrusted.instance_eval(code)
  end

  def load_trusted(code)
    @trusted.instance_eval(code)
  end

  def add_receiver(args = {})
    @server.add_receiver(name: args.fetch(:name), receiver: args.fetch(:object))
  end

  def client_for(args = {})
    receiver_name = args.fetch(:receiver_name)
    @clients[receiver_name] ||= PipeRpc::Client.new(socket: @socket, receiver_name: receiver_name)
  end
end

class Sandbox::Controller
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def clear
    @sandbox.clear
  end

  def load_untrusted(code)
    @sandbox.load_untrusted(code)
  end

  def load_trusted(code)
    @sandbox.load_trusted(code)
  end
end

class Sandbox::Untrusted < Module; end

class Sandbox::Trusted < Module
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def untrusted_code
    @sandbox.untrusted
  end

  def export(args = {})
    @sandbox.add_receiver(name: args.fetch(:as), receiver: args.fetch(:object))
  end

  def import(name)
    @sandbox.client_for(receiver_name: name)
  end
end

Object.remove_const(:Sandbox).new