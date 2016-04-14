describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::MrubySandbox.new }
  before { sandbox.start_logging }
  after{ sandbox.close }

  it "can eval code" do
    expect(sandbox.eval('5+8')).to be 13
  end

  it "reports back low level errors like SyntaxError" do
    expect{ sandbox.eval('cass Test; end') }.to raise_error(PipeRpc::InternalError, /syntax error/)
  end

  it "can be closed" do
    expect{ sandbox.eval('2') }.to be 2
    sandbox.close
    expect{ sandbox.eval('2') }.to raise_error(PipeRpc::ClosedError)
  end

  describe "The environment the code is eval'd in" do
    it "does not have access to some constants" do
      expect{ sandbox.eval('::Sandbox')     }.to raise_error(PipeRpc::InternalError, 'uninitialized constant Sandbox')
      expect{ sandbox.eval('Sandbox')       }.to raise_error(PipeRpc::InternalError, 'uninitialized constant Sandbox')
      expect{ sandbox.eval('::IO')          }.to raise_error(PipeRpc::InternalError, 'uninitialized constant IO')
      expect{ sandbox.eval('::PipeRpc')     }.to raise_error(PipeRpc::InternalError, 'uninitialized constant PipeRpc')
      expect{ sandbox.eval('::GC')          }.to raise_error(PipeRpc::InternalError, 'uninitialized constant GC')
      expect{ sandbox.eval('::ObjectSpace') }.to raise_error(PipeRpc::InternalError, 'uninitialized constant ObjectSpace')
    end

    it "cannot eval code in the context of a server" do
      class Safe < MrubySandbox::Server
        def initialize
          @inside = 'abc'
        end
      end

      sandbox.servers.add(safe: Safe.new)
      expect{ sandbox.eval 'client_for(:safe).instance_eval', __FILE__, __LINE__ }.to raise_error(
          PipeRpc::InternalError, "undefined method `instance_eval' for <Client:safe>")
    end

    it 'can be send code in multiple calls' do
      sandbox.eval(<<-CODE)
        def meth
          'result'
        end
      CODE

      sandbox.eval(<<-CODE)
        module Mod; end

        class Klass
          def meth
            'klass meth'
          end
        end
      CODE

      expect(sandbox.eval('Mod')).to match /Mod$/
      expect(sandbox.eval('Klass')).to match /Klass/
      expect(sandbox.eval('Klass.new.meth')).to eq 'klass meth'
      expect(sandbox.eval('meth')).to eq 'result'
    end

    it "can create a server for requests" do
      sandbox.eval(<<-CODE, __FILE__, __LINE__)
        class Calc
          def multiply(a, b)
            a * b
          end
        end
        add_server(math: Calc.new)
      CODE

      client = sandbox.clients[:math]
      expect(client.multiply(5, 9)).to be 45
      expect{ client.multiply('a', 'b') }.to raise_error(PipeRpc::InternalError)
      expect{ client.multiply(3) }.to raise_error(ArgumentError)
      expect{ client.exp }.to raise_error(NoMethodError)
    end

    it "can summon a client to talk to a server" do
      class Calc < MrubySandbox::Server
        def exp(a, b)
          a ** b
        end
      end
      sandbox.servers.add(math: Calc.new)

      expect(sandbox.eval 'client_for(:math)').to eq '<Client:math>'
      expect(sandbox.eval 'client_for(:math).exp(2,8)').to be 256
      expect{ sandbox.eval 'client_for(:math).exp(nil,:b)', __FILE__, __LINE__ }.to raise_error(
          PipeRpc::ReflectedError, "undefined method `**' for nil:NilClass")
      expect{ sandbox.eval 'client_for(:math).exp', __FILE__, __LINE__ }.to raise_error(
          PipeRpc::InternalError, "wrong number of arguments (0 for 2)")
      expect{ sandbox.eval 'client_for(:math).add', __FILE__, __LINE__ }.to raise_error(
          PipeRpc::InternalError, "undefined method `add' for <Client:math>")
    end

    it "can call a server method outside the sandbox while handling a request" do
      sandbox.eval(<<-CODE)
        class Calc
          def initialize(untrusted)
            @math = untrusted.client_for(:math)
          end

          def square(a)
            @math.multiply(a, a)
          end
        end
        add_server(math: Calc.new(self))
      CODE

      class Calc < MrubySandbox::Server
        def multiply(a, b)
          a * b
        end
      end
      sandbox.servers.add(math: Calc.new)

      expect(sandbox.clients[:math].square(5)).to be 25
    end
  end
end