require 'world_object'

require_relative 'mruby_sandbox/version'

module MrubySandbox
  class Sandbox < WorldObject::Connection
    self.world_class = 'mrubySandbox'

    def self.executable
      @executable ||= begin
        executable = File.join File.dirname(__FILE__), '..', 'bin', 'mruby_sandbox'
        unless File.exists? executable
          raise Error, "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
        end
        executable
      end
    end

    def initialize(opts = {})
      (input, mrb_output), (mrb_input, output) = IO.pipe, IO.pipe
      @pid = spawn self.class.executable, in: mrb_input, out: mrb_output
      mrb_input.close; mrb_output.close
      super opts.merge(input: input, output: output)
    end

    on :negotiation do |ambassador|
      ambassador.negotiate_ruby_symbol_extension
    end

    on :closed do
      Process.kill 9, @pid
      Process.wait @pid
      @pid = nil
    end

    attr_reader :pid

    def evaluate(*args)
      peer.evaluate(*args)
    rescue Exception => e
      e.backtrace.delete_at e.backtrace.find_index{ |loc| loc.start_with? __FILE__ }
      raise e
    end
  end

  class Error < WorldObject::Error; end
end