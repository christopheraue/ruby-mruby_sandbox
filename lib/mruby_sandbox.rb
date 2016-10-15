require 'world_object'

require_relative 'mruby_sandbox/version'

module MrubySandbox
  class Sandbox < WorldObject::Gate
    world_class 'RUBY'

    def initialize(id = nil)
      input, w = IO.pipe
      r, output  = IO.pipe
      @pid = spawn(executable, in: r, out: w)
      r.close; w.close

      super (id || "pid#{@pid}"), input: input, output: output
      self.ruby_symbol_ext_type = 3
      handle_message # to get peer

    rescue Errno::ENOENT => e
      STDERR.puts "The mruby_sandbox executable is missing. Run `build_mruby_sandbox` first."
      fail e
    end

    def inject(*args)
      peer.inject(*args)
    end

    def eval(*args)
      peer.eval(*args)
    end

    def close(*)
      return unless @pid
      super
      Process.kill 9, @pid
      Process.wait @pid
      @pid = nil
    end

    private def executable
      current_dir = File.expand_path(File.dirname(__FILE__))
      File.join(current_dir, '../bin/mruby_sandbox')
    end
  end
end