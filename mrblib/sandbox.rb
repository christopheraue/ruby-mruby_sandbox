class Sandbox
  # Remove constants from global namespace so no one can mess around with it.
  IO = Object.remove_const :IO
  PipeRpc = Object.remove_const :PipeRpc

  def initialize
    clear
    @input = IO.new(0)  #STDIN
    @output = IO.new(1) #STDOUT
    @server = PipeRpc::Server.new(input: @input, output: @output, handler: Handler.new(self))
    @clients = {}
    @server.listen
  end

  attr_reader :untrusted

  def clear
    @untrusted = Untrusted.new
    @trusted = Trusted.new(self)
    true
  end

  def eval_untrusted(code)
    @untrusted.instance_eval(code)
  end

  def eval_trusted(code)
    @trusted.instance_eval(code)
  end

  def add_handler(args)
    @server.add_handler(name: args.fetch(:name), handler: args.fetch(:object))
  end

  def client_for(args)
    handler_name = args.fetch(:handler_name)
    @clients[handler_name] ||= PipeRpc::Client.new(input: @input, output: @output,
      handler_name: handler_name)
  end
end

class Sandbox::Handler
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

class Sandbox::Untrusted < Module; end

class Sandbox::Trusted < Module
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def untrusted_code
    @sandbox.untrusted
  end

  def export(args)
    @sandbox.add_handler(name: args.fetch(:as), handler: args.fetch(:object))
  end

  def import(args)
    @sandbox.client_for(handler_name: args.fetch(:name))
  end
end

Object.remove_const(:Sandbox).new