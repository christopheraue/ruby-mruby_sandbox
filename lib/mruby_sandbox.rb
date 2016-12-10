require 'world_object'

require_relative 'mruby_sandbox/version'

module MrubySandbox
  class Sandbox < WorldObject::Connection
    def initialize
      input, mrb_output = IO.pipe
      mrb_input, output  = IO.pipe
      @pid = spawn(executable, in: mrb_input, out: mrb_output)
      mrb_input.close; mrb_output.close

      super WorldObject::StreamSocket.new(input: input, output: output)

      welcome
      @message_pack.symbol_ext_type = peer.set_ruby_symbol_ext_type_to 2
    end

    attr_reader :pid

    def inject(*args)
      peer.inject(*args)
    end

    def evaluate(*args)
      peer.evaluate(*args)
    end

    def dismiss(*)
      super
      Process.kill 9, @pid
      Process.wait @pid
      @pid = nil
    end

    private def executable
      path = File.join File.dirname(__FILE__), '..', 'bin', 'mruby_sandbox'
      if File.exists? path
        path
      else
        raise Error, "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
      end
    end
  end

  class Sandbox::Interface < WorldObject::Connection::Interface
    world_class 'MrubySandboxSupervisor'
    world_instance{ "pid#{@connection.pid}" or __id__ }
  end

  class Error < StandardError; end
end