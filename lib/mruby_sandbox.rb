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

    on :opened do
      negotiate_symbol_extension
    end

    attr_reader :pid

    def inject(*args)
      peer.inject(*args)
    end

    def evaluate(*args)
      peer.evaluate(*args)
    end

    def close(*)
      super
      Process.kill 9, @pid
      Process.wait @pid
      @pid = nil
    end
  end

  class Error < WorldObject::Error; end
end