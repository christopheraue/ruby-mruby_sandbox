require 'pipe_rpc'
require 'forwardable'

class MrubySandbox
  extend Forwardable

  def self.finalize(pid)
    Proc.new do
      Process.kill 9, pid
      Process.wait pid
    end
  end

  def initialize
    input, w = IO.pipe
    r, output  = IO.pipe
    pid = spawn('bin/mruby_sandbox', in: r, out: w )
    r.close; w.close
    ObjectSpace.define_finalizer(self, self.class.finalize(pid))
    socket = PipeRpc::Socket.new(input: input, output: output)
    @server = PipeRpc::Server.new(socket: socket)
    @clients = {}
  end

  def client_for(receiver)
    @clients[receiver] ||= @server.new_linked_client(receiver)
  end

  def client
    client_for :default
  end

  delegate [:clear, :eval_trusted, :eval_untrusted] => :client
  delegate [:add_receiver, :rmv_receiver, :socket] => :@server
end