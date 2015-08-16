require 'pipe_rpc'
require 'forwardable'
require_relative 'mruby_sandbox/version'
require_relative 'mruby_sandbox/server'

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
    pid = spawn(executable, in: r, out: w )
    r.close; w.close

    ObjectSpace.define_finalizer(self, self.class.finalize(pid))

    @hub = PipeRpc::Hub.new(input: input, output: output)

  rescue Errno::ENOENT => e
    STDERR.puts "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
    fail e
  end

  def client
    client_for :default
  end

  delegate [:clear, :eval] => :client
  delegate [:add_server, :rmv_server, :client_for, :channel, :handle_message, :loop_iteration=] => :@hub
  alias_method :export, :add_server

  private

  def executable
    current_dir = File.expand_path(File.dirname(__FILE__))
    File.join(current_dir, '../bin/mruby_sandbox')
  end
end