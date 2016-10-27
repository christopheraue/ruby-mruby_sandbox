describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::Sandbox.new.tap(&:open) }
  #before { sandbox.start_logging }
  after{ sandbox.close if sandbox.open? }

  it "can eval code" do
    expect(sandbox.eval('5+8')).to be 13
  end

  it "reports back low level errors like SyntaxError" do
    expect{ sandbox.eval('cass Test; end') }.to raise_error(WorldObject::InternalError, /syntax error/)
  end

  it "can be closed" do
    expect{ sandbox.eval('2') }.to be 2
    sandbox.close('reason')
    expect{ sandbox.eval('2') }.to raise_error(WorldObject::GateClosedError, 'reason')
  end

  it "exposes the correct methods" do
    expect{ sandbox.methods.to contain_exactly(:eval, :inject, :methods, :respond_to?) }
  end

  it "preserves standard types coming from inside the sandbox" do
    expect{ sandbox.eval('nil') }.to be nil
    expect{ sandbox.eval('false') }.to be false
    expect{ sandbox.eval('true') }.to be true
    expect{ sandbox.eval('1') }.to be 1
    expect{ sandbox.eval('1.2') }.to be 1.2
    expect{ sandbox.eval('"string"') }.to eq "string"
    expect{ sandbox.eval(':symbol') }.to be :symbol
    expect{ sandbox.eval('[]') }.to eq []
    expect{ sandbox.eval('{}') }.to eq({})
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

    expect(sandbox.eval 'preserve.nil == nil').to be true
    expect(sandbox.eval 'preserve.false == false').to be true
    expect(sandbox.eval 'preserve.true == true').to be true
    expect(sandbox.eval 'preserve.int == 1').to be true
    expect(sandbox.eval 'preserve.float == 1.2').to be true
    expect(sandbox.eval 'preserve.string == "string"').to be true
    expect(sandbox.eval 'preserve.symbol == :symbol').to be true
    expect(sandbox.eval 'preserve.array == [:item1, :item2]').to be true
    expect(sandbox.eval 'preserve.hash_obj == { key: :value }').to be true
  end

  it "converts objects of custom types to strings" do
    expect{ sandbox.eval('class Test; end; Test.new') }.to match /#<Test:0x[0-9a-f]+>/
  end

  describe "The environment the code is eval'd in" do
    it "cannot eval code in the context of a server" do
      stub_const('Safe', Module.new)
      WorldObject.register_servable Safe

      sandbox.inject Safe, as: 'Kernel#safe'

      expect{ sandbox.eval 'safe.eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.eval")

      expect{ sandbox.eval 'safe.instance_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.instance_eval")
      expect{ sandbox.eval 'safe.instance_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.instance_exec")

      expect{ sandbox.eval 'safe.class_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.class_eval")
      expect{ sandbox.eval 'safe.class_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.class_exec")

      expect{ sandbox.eval 'safe.module_eval', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.module_eval")
      expect{ sandbox.eval 'safe.module_exec', __FILE__, __LINE__ }.to raise_error(
        WorldObject::InternalError, "error inside MRUBY.eval: undefined method Safe.module_exec")
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

      expect(sandbox.eval('Mod')).to eq 'Mod'
      expect(sandbox.eval('Klass')).to eq 'Klass'
      expect(sandbox.eval('Klass.new.meth')).to eq 'klass meth'
      expect(sandbox.eval('meth')).to eq 'result'
    end

    it "can create a server for requests" do
      client = sandbox.eval(<<-CODE, __FILE__, __LINE__)
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

      sandbox.eval "module Calcu; end"

      sandbox.inject Calc, as: 'Calcu.lator'

      expect(sandbox.eval 'Calcu.lator').to be Calc
      expect(sandbox.eval 'Calcu.lator.exp(2,8)').to be 256
      expect{ sandbox.eval 'Calcu.lator.exp(nil,:b)', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.eval: error inside Calc.exp: undefined method `**' for nil:NilClass")
      expect{ sandbox.eval 'Calcu.lator.exp', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.eval: invalid arguments for Calc.exp: wrong number of arguments (given 0, expected 2)")
      expect{ sandbox.eval 'Calcu.lator.add', __FILE__, __LINE__ }.to raise_error(
          WorldObject::InternalError, "error inside MRUBY.eval: undefined method Calc.add")
    end

    it "can evaluate a roundtrip using client wrapper and subject server" do
      stub_const('Calc', Class.new)
      Calc.class_eval do
        WorldObject.register_servable self

        world_public def multiply(a, b)
          a * b
        end
      end

      sandbox.eval(<<-CODE)
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