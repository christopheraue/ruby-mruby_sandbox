class Sandbox < PipeRpc::Gateway
  def initialize(main)
    input = IO.new(0, 'r')  #STDIN
    output = IO.new(1, 'w') #STDOUT
    super(input: input, output: output)

    servers.add(default: main)

    sandbox = self

    Object.define_method :add_server do |*args|
      sandbox.servers.add(*args)
    end

    Object.define_method :client_for do |server|
      sandbox.clients[server]
    end
  end

  def run
    loop do
      handle_message # blocks every iteration
    end
  end
end

def eval(code, file = '', lineno = 0)
  super(code, nil, file, lineno)
end

Server = PipeRpc::Server
SubjectServer = PipeRpc::SubjectServer
Client = PipeRpc::Client
ClientWrapper = PipeRpc::ClientWrapper

# Remove constants from global namespace code should not directly interact with
Sandbox::IO = Object.remove_const(:IO)
Sandbox::PipeRpc = Object.remove_const(:PipeRpc)
Object.remove_const(:Sandbox).new(self).run