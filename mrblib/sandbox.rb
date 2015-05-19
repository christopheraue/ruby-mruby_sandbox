class Sandbox
  # Remove constants from global namespace so no one can mess around with it.
  IO = Object.remove_const :IO
  LocalRpc = Object.remove_const :LocalRpc

  attr_reader :input, :output, :server, :untrusted, :trusted

  def initialize
    @input = IO.new(0)  #STDIN
    @output = IO.new(1) #STDOUT
    @server = LocalRpc::Server.new(input: @input, output: @output, handler: self)
    discard
    loop do
      IO.select [@input]
      server.handle_request # responses to clients are dealt with synchronously so we don't need to
                            # handle them here, too.
    end
  end

  def discard
    @untrusted = Untrusted.new
    @trusted = Trusted.new(sandbox)
    true
  end

  def load_untrusted(code)
    @untrusted.instance_eval(code)
  end

  def load_trusted(code)
    @trusted.instance_eval(code)
  end

  class Untrusted < Class; end

  class Trusted < Class
    def initialize(sandbox)
      @sandbox = sandbox
    end

    def untrusted_code
      @sandbox.untrusted
    end

    def act_as_rpc_handler(object:, handler_name:)
      @sandbox.server.add_handler(name: handler_name, handler: object)
    end

    def act_as_rpc_client(object:, handler_name:)
      client = LocalRpc::Client.new(input: @sandbox.input, output: @sandbox.output, handler_name: handler_name)
      object.instance_eval do
        define_method(handler_name) do
          client
        end
      end
    end
  end
end

Object.remove_const(:Sandbox).new