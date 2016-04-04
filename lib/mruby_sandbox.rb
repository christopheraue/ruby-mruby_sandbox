require 'pipe_rpc'
require 'forwardable'
require 'logger'
require_relative 'mruby_sandbox/version'
require_relative 'mruby_sandbox/server'

class MrubySandbox
  extend Forwardable

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  def initialize
    input, w = IO.pipe
    r, output  = IO.pipe
    @pid = spawn(executable, in: r, out: w)
    r.close; w.close

    self.class.logger.debug "Sandbox(#{__id__}) created with process #{@pid}"

    @hub = PipeRpc::Hub.new(input: input, output: output)
    @data = {}

  rescue Errno::ENOENT => e
    STDERR.puts "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
    fail e
  end

  attr_reader :data

  def client
    client_for :default
  end

  delegate [:clear, :eval] => :client
  delegate [:add_server, :rmv_server, :client_for, :channel, :handle_message, :loop_iteration=,
    :on_sent, :on_received, :on_incoming_request] => :@hub
  alias_method :export, :add_server

  def start_logging
    @hub.logger = proc do |message|
      self.class.logger.debug "Sandbox(#{__id__}) #{message}"
    end
  end

  def reflect_logger_server=(server)
    client.debug_mode(!!server)
    if server
      add_server(reflect_logger: server)
    else
      rmv_server(:reflect_logger)
    end
  end

  def tear_down
    return unless @pid
    @hub.cancel
    Process.kill 9, @pid
    Process.wait @pid
    self.class.logger.debug "Sandbox(#{__id__}) teared down and process #{@pid} killed"
    @pid = nil
  end

  private

  def executable
    current_dir = File.expand_path(File.dirname(__FILE__))
    File.join(current_dir, '../bin/mruby_sandbox')
  end
end