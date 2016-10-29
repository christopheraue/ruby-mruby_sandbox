require 'world_object'

require_relative 'mruby_sandbox/version'

module MrubySandbox
  class Sandbox < WorldObject::Gate
    world_class 'RUBY'

    def open
      input, mrb_output = IO.pipe
      mrb_input, output  = IO.pipe
      @pid = spawn(executable, in: mrb_input, out: mrb_output)
      mrb_input.close; mrb_output.close

      super input: input, output: output
      self.ruby_symbol_ext_type = 3
    end

    def inject(*args)
      open unless open?
      peer.inject(*args)
    end

    def eval(*args)
      open unless open?
      peer.eval(*args)
    end

    def close(*)
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

  class Error < StandardError; end
end