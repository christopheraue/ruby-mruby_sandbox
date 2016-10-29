describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::Sandbox.new }
  #before { sandbox.start_logging }
  after{ sandbox.close if sandbox.open? }

  it "can eval code" do
    expect(sandbox.evaluate('5+8')).to be 13
  end

  it "reports back low level errors like SyntaxError" do
    expect{ sandbox.evaluate('cass Test; end') }.to raise_error(WorldObject::InternalError, /syntax error/)
  end

  it "reopens itself after being closed when sending a request directly to the gate" do
    expect{ sandbox.evaluate('2') }.to be 2
    sandbox.close('reason')
    expect{ sandbox.evaluate('2') }.to be 2
  end

  it "does not reopen itself after being closed when sending a request to a server" do
    client = sandbox.evaluate <<-CODE
      class Klass
        WorldObject.register_servable self
        world_public def one; 1 end
      end
      Klass.new
    CODE

    expect{ client.one }.to be 1
    sandbox.close('reason')
    expect{ client.one }.to raise_error(WorldObject::GateClosedError, 'reason')
  end

  it "exposes the correct methods" do
    expect{ sandbox.methods.to contain_exactly(:evaluate, :inject, :methods, :respond_to?) }
  end

  it "preserves standard types coming from inside the sandbox" do
    expect{ sandbox.evaluate('nil') }.to be nil
    expect{ sandbox.evaluate('false') }.to be false
    expect{ sandbox.evaluate('true') }.to be true
    expect{ sandbox.evaluate('1') }.to be 1
    expect{ sandbox.evaluate('1.2') }.to be 1.2
    expect{ sandbox.evaluate('"string"') }.to eq "string"
    expect{ sandbox.evaluate(':symbol') }.to be :symbol
    expect{ sandbox.evaluate('[]') }.to eq []
    expect{ sandbox.evaluate('{}') }.to eq({})
  end

  it "preserves standard types coming from outside the sandbox" do
    class Preserve
      WorldObject.register_servable self

      world_public def nil; nil end
      world_public def false; false end
      world_public def true; true end
      world_public def int; 1 end
      world_public def float; 1.2 end
      world_public def string; 'string' end
      world_public def symbol; :symbol end
      world_public def array; [:item1, :item2] end
      world_public def hash_obj; { key: :value } end
    end

    sandbox.inject Preserve.new, as: :preserve

    expect(sandbox.evaluate 'preserve.nil == nil').to be true
    expect(sandbox.evaluate 'preserve.false == false').to be true
    expect(sandbox.evaluate 'preserve.true == true').to be true
    expect(sandbox.evaluate 'preserve.int == 1').to be true
    expect(sandbox.evaluate 'preserve.float == 1.2').to be true
    expect(sandbox.evaluate 'preserve.string == "string"').to be true
    expect(sandbox.evaluate 'preserve.symbol == :symbol').to be true
    expect(sandbox.evaluate 'preserve.array == [:item1, :item2]').to be true
    expect(sandbox.evaluate 'preserve.hash_obj == { key: :value }').to be true
  end

  it "converts objects of custom types to strings" do
    expect{ sandbox.evaluate('class Test; end; Test.new') }.to match /#<Test:0x[0-9a-f]+>/
  end

  describe "The environment the code is eval'd in" do
    it "cannot eval code in the context of a server" do
      stub_const('Safe', Module.new)
      WorldObject.register_servable Safe

      sandbox.inject Safe, as: 'Kernel#safe'

      expect{ sandbox.evaluate 'safe.eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.eval")

      expect{ sandbox.evaluate 'safe.instance_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.instance_eval")
      expect{ sandbox.evaluate 'safe.instance_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.instance_exec")

      expect{ sandbox.evaluate 'safe.class_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.class_eval")
      expect{ sandbox.evaluate 'safe.class_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.class_exec")

      expect{ sandbox.evaluate 'safe.module_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.module_eval")
      expect{ sandbox.evaluate 'safe.module_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Safe.module_exec")
    end

    it 'can be send code in multiple calls' do
      sandbox.evaluate(<<-CODE)
        def meth
          'result'
        end
      CODE

      sandbox.evaluate(<<-CODE)
        module Mod; end

        class Klass
          def meth
            'klass meth'
          end
        end
      CODE

      expect(sandbox.evaluate('Mod')).to eq 'Mod'
      expect(sandbox.evaluate('Klass')).to eq 'Klass'
      expect(sandbox.evaluate('Klass.new.meth')).to eq 'klass meth'
      expect(sandbox.evaluate('meth')).to eq 'result'
    end

    it "can create a server for requests" do
      client = sandbox.evaluate(<<-CODE, __FILE__, __LINE__)
        class Calc
          WorldObject.register_servable self

          world_public def multiply(a, b)
            a * b
          end
        end

        Calc.new
      CODE

      expect(client.multiply(5, 9)).to be 45
      expect{ client.exp }.to raise_error(WorldObject::NoMethodError)
      expect{ client.multiply(3) }.to raise_error(WorldObject::ArgumentError)
      expect{ client.multiply('a', 'b') }.to raise_error(WorldObject::InternalError)
    end

    it "can summon a client to talk to a server" do
      stub_const('Calc', Module.new)
      Calc.class_eval do
        WorldObject.register_servable self

        class << self
          world_public def exp(a, b)
            a ** b
          end
        end
      end

      sandbox.evaluate "module Calcu; end"

      sandbox.inject Calc, as: 'Calcu.lator'

      expect(sandbox.evaluate 'Calcu.lator').to be Calc
      expect(sandbox.evaluate 'Calcu.lator.exp(2,8)').to be 256
      expect{ sandbox.evaluate 'Calcu.lator.exp(nil,:b)', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.evaluate: error inside Calc.exp: undefined method `**' for nil:NilClass")
      expect{ sandbox.evaluate 'Calcu.lator.exp', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.evaluate: invalid arguments for Calc.exp: wrong number of arguments (given 0, expected 2)")
      expect{ sandbox.evaluate 'Calcu.lator.add', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.evaluate: undefined method Calc.add")
    end

    it "can evaluate a roundtrip using client wrapper and subject server" do
      stub_const('Calc', Class.new)
      Calc.class_eval do
        WorldObject.register_servable self

        world_public def multiply(a, b)
          a * b
        end
      end

      sandbox.evaluate(<<-CODE)
        class Calc
          WorldObject.register_servable self
          Sandbox.register_client_wrapper self

          world_public def square(a)
            multiply(a, a)
          end
        end
      CODE

      client = sandbox.inject Calc.new
      expect(client.square(5)).to be 25
    end
  end
end