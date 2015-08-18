class Sandbox < BasicObject
  def initialize
    clear
    input = IO.new(0, 'r')  #STDIN
    output = IO.new(1, 'w') #STDOUT
    @hub = PipeRpc::Hub.new(input: input, output: output)
    add_server(default: Controller.new(self))
    ::Kernel.loop do
      begin
        @hub.handle_message # blocks every iteration
      rescue ::StandardError => e
        # reflect errors back to the managing process
        backtrace = e.backtrace
        @hub.send_error(code: -32603, data: { message: e.message, backtrace: backtrace })
      end
    end
  end

  def clear
    @untrusted = ::Untrusted.new(self)
    true
  end

  def eval(code, file = '', lineno = 0)
    @untrusted.eval(code, file, lineno)
  end

  def add_server(args = {})
    @hub.add_server(args)
  end

  def client_for(server_name)
    @hub.client_for(server_name)
  end
end

class Sandbox::Controller
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def clear
    @sandbox.clear
  end

  def eval(code, file = '', lineno = 0)
    @sandbox.eval(code, file, lineno)
  end
end

class Untrusted < Module
  def initialize(sandbox)
    @sandbox = sandbox
  end

  def eval(code, file = '', lineno = 0)
    instance_eval(code, file, lineno)
  end

  def export(args = {})
    @sandbox.add_server(args)
  end

  def client_for(server = :default)
    @sandbox.client_for(server)
  end
  alias_method :client, :client_for
end

# Remove constants from global namespace so untrusted code cannot mess around with it.
Sandbox::GC = Object.remove_const(:GC)
Sandbox::ObjectSpace = Object.remove_const(:ObjectSpace)
Sandbox::IO = Object.remove_const(:IO)
Sandbox::PipeRpc = Object.remove_const(:PipeRpc)
Object.remove_const(:Sandbox).new