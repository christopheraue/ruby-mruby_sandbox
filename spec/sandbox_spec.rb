describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::Sandbox.new }
  # before { sandbox.interaction_logger.start }
  # before { sandbox.peer.start_logging }
  after{ sandbox.close('end of spec') unless sandbox.closed? }

  it "can eval code" do
    expect(sandbox.evaluate('5+8')).to be 13
  end

  it "has only limited access to IO functionality" do
    expect{ sandbox.evaluate('File') }.to raise_error(WorldObject::InternalError, include('uninitialized constant File'))
    expect{ sandbox.evaluate('FileTest') }.to raise_error(WorldObject::InternalError, include('uninitialized constant FileTest'))

    expect(sandbox.evaluate('IO.methods(false)')).to contain_exactly *%i(_sysclose for_fd select
      _pipe pipe open new inherited initialize superclass)

    expect(sandbox.evaluate('IO.instance_methods(false)')).to contain_exactly *%i(initialize
      _check_readable isatty sync sync= sysread sysseek syswrite close close_on_exec= close_on_exec?
      closed? fileno flush write << eof? eof pos tell pos= rewind seek _read_buf ungetc read
      readline gets readchar getc each each_byte each_line each_char readlines puts print printf
      to_i tty? binmode)

    expect(sandbox.evaluate('Kernel.methods(false)')).not_to include :`
    expect(sandbox.evaluate('Kernel.instance_methods(false)')).not_to include *%i(print puts printf gets getc open)
  end

  it "reports back low level errors like SyntaxError" do
    expect{ sandbox.evaluate('cass Test; end') }.to raise_error(WorldObject::InternalError, /syntax error/)
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
    expect{ client.one }.to raise_error(WorldObject::ConnectionClosedError, 'reason')
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

    client = sandbox.evaluate(<<-CODE, __FILE__, __LINE__+1)
      class Servable
        WorldObject.register_servable self

        world_public def nil; preserve.nil end
        world_public def false; preserve.false end
        world_public def true; preserve.true end
        world_public def int; preserve.int end
        world_public def float; preserve.float end
        world_public def string; preserve.string end
        world_public def symbol; preserve.symbol end
        world_public def array; preserve.array end
        world_public def hash_obj; preserve.hash_obj end
      end

      Servable.new
    CODE

    expect(client.nil).to be nil
    expect(client.false).to be false
    expect(client.true).to be true
    expect(client.int).to be 1
    expect(client.float).to be 1.2
    expect(client.string).to eq 'string'
    expect(client.symbol).to be :symbol
    expect(client.array).to eq [:item1, :item2]
    expect(client.hash_obj).to eq(key: :value)
  end

  it "converts objects of custom types to strings" do
    expect{ sandbox.evaluate('class Test; end; Test.new') }.to match /#<Test:0x[0-9a-f]+>/
  end

  describe "The environment the code is eval'd in" do
    it "cannot eval code in the context of a server" do
      stub_const('Safe', Module.new)
      WorldObject.register_servable Safe

      sandbox.inject Safe, as: 'Object#safe'

      client = sandbox.evaluate(<<-CODE, __FILE__, __LINE__+1)
        module Servable
          WorldObject.register_servable self
        end

        class << Servable
          world_public def test_eval; safe.eval end
          world_public def test_instance_eval; safe.instance_eval end
          world_public def test_instance_exec; safe.instance_exec end
          world_public def test_class_eval; safe.class_eval end
          world_public def test_class_exec; safe.class_exec end
          world_public def test_module_eval; safe.module_eval end
          world_public def test_module_exec; safe.module_exec end
        end

        Servable
      CODE

      expect{ client.test_eval }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_eval: undefined method Safe.eval")

      expect{ client.test_instance_eval }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_instance_eval: undefined method Safe.instance_eval")
      expect{ client.test_instance_exec }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_instance_exec: undefined method Safe.instance_exec")

      expect{ client.test_class_eval }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_class_eval: undefined method Safe.class_eval")
      expect{ client.test_class_exec }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_class_exec: undefined method Safe.class_exec")

      expect{ client.test_module_eval }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_module_eval: undefined method Safe.module_eval")
      expect{ client.test_module_exec }.to raise_error(
        WorldObject::InternalError, "error inside Servable.test_module_exec: undefined method Safe.module_exec")
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
      client = sandbox.evaluate(<<-CODE, __FILE__, __LINE__+1)
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

      calcu = sandbox.evaluate(<<-CODE, __FILE__, __LINE__+1)
        module Calcu
          WorldObject.register_servable self
        end

        class << Calcu
          world_public def pow(*args)
            lator.exp(*args)
          end

          world_public def plus(*args)
            lator.add(*args)
          end

          world_public :lator
        end

        Calcu
      CODE

      sandbox.inject Calc, as: 'Calcu.lator'

      expect(calcu.lator).to be Calc
      expect(calcu.pow(2, 8)).to be 256
      expect{ calcu.pow(nil,:b) }.to raise_error(
          WorldObject::InternalError, "error inside Calcu.pow: error inside Calc.exp: undefined method `**' for nil:NilClass")
      expect{ calcu.pow }.to raise_error(
          WorldObject::InternalError, "error inside Calcu.pow: invalid arguments for Calc.exp: wrong number of arguments (given 0, expected 2)")
      expect{ calcu.plus }.to raise_error(
          WorldObject::InternalError, "error inside Calcu.plus: undefined method Calc.add")
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