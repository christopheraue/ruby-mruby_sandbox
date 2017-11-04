describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::Sandbox.open }
  # before { MrubySandbox::Sandbox.logger = Logger.new(STDOUT) }
  after{ sandbox.close('end of spec') unless sandbox.closed? }

  it "can eval code" do
    expect(sandbox.evaluate('5+8')).to be 13
  end

  it "has only limited access to IO functionality" do
    expect{ sandbox.evaluate('File') }.to raise_error(WorldObject::RemoteError, include('uninitialized constant File'))
    expect{ sandbox.evaluate('FileTest') }.to raise_error(WorldObject::RemoteError, include('uninitialized constant FileTest'))

    expect(sandbox.evaluate('IO.methods(false)')).to contain_exactly *%i(_sysclose for_fd select
      _pipe pipe open new inherited initialize superclass __original_new__ allocate)

    expect(sandbox.evaluate('IO.instance_methods(false)')).to contain_exactly *%i(initialize
      _check_readable isatty sync sync= sysread sysseek syswrite close close_on_exec= close_on_exec?
      closed? fileno flush hash write << eof? eof pos tell pos= rewind seek _read_buf ungetc read
      readline gets readchar getc each each_byte each_line each_char readlines puts print printf
      to_i tty? binmode await_readable await_writable read_nonblock write_nonblock
      await_read await_written concurrently_read concurrently_write)

    expect(sandbox.evaluate('Kernel.instance_methods(false)')).not_to include *%i(` print puts printf gets getc open)
  end

  it "reports back low level errors like SyntaxError" do
    expect{ sandbox.evaluate('cass Test; end') }.to raise_error(WorldObject::RemoteError, /syntax error/)
  end

  it "includes a backtrace in errors" do
    eval_line = __LINE__+2
    def test_eval
      sandbox.evaluate <<-CODE.strip_heredoc, __FILE__, __LINE__+1
        def a; raise 'error' end
        def b; a end
        def c; b end
        c
      CODE
    end

    expect{ test_eval }.to raise_error do |error|
      expect(error.backtrace).to start_with(
        "#{__FILE__}:#{eval_line+1}:in a",
        "#{__FILE__}:#{eval_line+2}:in b",
        "#{__FILE__}:#{eval_line+3}:in c",
        "#{__FILE__}:#{eval_line+4}:in evaluate",
        "#{__FILE__}:#{eval_line+0}:in `test_eval'")
    end
  end

  it "does not reopen itself after being closed when sending a request to a server" do
    client = sandbox.evaluate <<-CODE.strip_heredoc
      class Klass
        include Sandbox::WorldObject
        world_public def one; 1 end
      end
      Klass.new
    CODE

    expect{ client.one }.to be 1
    sandbox.close('reason')
    expect{ client.one }.to raise_error(WorldObject::ConnectionClosedError, 'reason')
  end

  it "exposes the correct methods" do
    expect{ sandbox.methods.to contain_exactly(:evaluate, :methods, :respond_to?) }
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
      include MrubySandbox::Sandbox::WorldObject
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

    sandbox.evaluate <<-CODE
      class Sandbox
        world_public def inject(world_object)
          Kernel.define_method(:preserve){ world_object }
        end
      end
    CODE

    sandbox.peer.inject Preserve.new

    client = sandbox.evaluate(<<-CODE.strip_heredoc, __FILE__, __LINE__+1)
      class Servable
        include Sandbox::WorldObject
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

  it "has no access to eval methods" do
    stub_const 'Safe', Module.new.extend(MrubySandbox::Sandbox::WorldObject['Safe'])

    sandbox.evaluate <<-CODE
      class Sandbox
        world_public def inject(world_object)
          Kernel.define_method(:safe){ world_object }
        end
      end
    CODE

    sandbox.peer.inject Safe

    client = sandbox.evaluate(<<-CODE.strip_heredoc, __FILE__, __LINE__+1)
      obj = Object.new.extend WorldObject['Servable']
      class << obj
        world_public def test_eval; safe.eval end
        world_public def test_instance_eval; safe.instance_eval end
        world_public def test_instance_exec; safe.instance_exec end
        world_public def test_class_eval; safe.class_eval end
        world_public def test_class_exec; safe.class_exec end
        world_public def test_module_eval; safe.module_eval end
        world_public def test_module_exec; safe.module_exec end
      end
      obj
    CODE

    expect{ client.test_eval }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_eval: <Remote>Safe.eval: undefined")

    expect{ client.test_instance_eval }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_instance_eval: <Remote>Safe.instance_eval: undefined")
    expect{ client.test_instance_exec }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_instance_exec: <Remote>Safe.instance_exec: undefined")

    expect{ client.test_class_eval }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_class_eval: <Remote>Safe.class_eval: undefined")
    expect{ client.test_class_exec }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_class_exec: <Remote>Safe.class_exec: undefined")

    expect{ client.test_module_eval }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_module_eval: <Remote>Safe.module_eval: undefined")
    expect{ client.test_module_exec }.to raise_error(
      WorldObject::RemoteError, "<Remote>Servable.test_module_exec: <Remote>Safe.module_exec: undefined")
  end
end