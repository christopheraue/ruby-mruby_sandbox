require 'pipe_rpc'
require 'forwardable'
require_relative 'mruby_sandbox/version'
require_relative 'mruby_sandbox/receiver'

class MrubySandbox
  extend Forwardable

  def self.finalize(pid)
    Proc.new do
      Process.kill 9, pid
      Process.wait pid
    end
  end

  def initialize(receiver = Receiver.new)
    input, w = IO.pipe
    r, output  = IO.pipe
    pid = spawn('bin/mruby_sandbox', in: r, out: w )
    r.close; w.close
    ObjectSpace.define_finalizer(self, self.class.finalize(pid))
    socket = PipeRpc::Socket.new(input: input, output: output)
    @server = PipeRpc::Server.new(socket: socket, receiver: receiver)
    @clients = {}
  end

  def client_for(receiver)
    @clients[receiver] ||= @server.new_linked_client(receiver)
  end

  def client
    client_for :default
  end

  delegate [:clear, :eval] => :client
  delegate [:add_receiver, :rmv_receiver, :socket, :handle_request] => :@server
end