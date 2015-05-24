class Sandbox
  def self.finalize(pid)
    Proc.new do
      Process.kill 9, pid
      Process.wait pid
    end
  end

  def initialize
    input, w = IO.pipe
    r, output  = IO.pipe
    pid = spawn('bin/mruby-sandbox', in: r, out: w )
    r.close; w.close
    ObjectSpace.define_finalizer(self, self.class.finalize(pid))
    @socket = PipeRpc::Socket.new(input: input, output: output)
  end

  attr_reader :socket
end