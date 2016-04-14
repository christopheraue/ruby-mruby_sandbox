require 'pipe_rpc'
require 'logger'

require_relative 'mruby_sandbox/version'
require_relative 'mruby_sandbox/server'

module MrubySandbox
  class MrubySandbox < PipeRpc::Gateway
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

      super(input: input, output: output)

    rescue Errno::ENOENT => e
      STDERR.puts "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
      fail e
    end

    def client
      clients[:default]
    end

    def eval(*args)
      client.eval(*args)
    end

    def start_logging
      on_sent do |message|
        self.class.logger.debug "Sandbox(#{__id__}) sent: #{message}"
      end

      on_received do |message|
        self.class.logger.debug "Sandbox(#{__id__}) received: #{message}"
      end
    end

    def close
      return unless @pid
      super
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
end