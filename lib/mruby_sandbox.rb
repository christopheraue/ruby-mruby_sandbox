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
    pid = spawn(executable, in: r, out: w )
    r.close; w.close
    ObjectSpace.define_finalizer(self, self.class.finalize(pid))
    socket = PipeRpc::Socket.new(input: input, output: output)
    @server = PipeRpc::Server.new(socket: socket, receiver: receiver)
    @clients = {}
  rescue Errno::ENOENT => e
    STDERR.puts "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
    fail e
  end

  def client_for(receiver)
    @clients[receiver] ||= @server.new_linked_client(receiver)
  end

  def client
    client_for :default
  end

  delegate [:clear, :eval] => :client
  delegate [:add_receiver, :rmv_receiver, :socket, :handle_request] => :@server

  private

  def executable
    current_dir = File.expand_path(File.dirname(__FILE__))
    File.join(current_dir, '../bin/mruby_sandbox')
  end
end