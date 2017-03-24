describe "The sandbox" do
  subject(:sandbox) { MrubySandbox::Sandbox.new }
  # before { MrubySandbox::Sandbox.logger.start }
  after{ sandbox.close('end of spec') unless sandbox.closed? }

  it "can eval code" do
    expect(sandbox.evaluate('5+8')).to be 13
  end

  it "has only limited access to IO functionality" do
    expect{ sandbox.evaluate('File') }.to raise_error(WorldObject::RemoteError, include('uninitialized constant File'))
    expect{ sandbox.evaluate('FileTest') }.to raise_error(WorldObject::RemoteError, include('uninitialized constant FileTest'))

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
    expect{ sandbox.evaluate('cass Test; end') }.to raise_error(WorldObject::RemoteError, /syntax error/)
  end

  it "does not reopen itself after being closed when sending a request to a server" do
    client = sandbox.evaluate <<-CODE.strip_heredoc
      class Klass
        include Sandbox::LocalObject
      end
      Sandbox::WorldInterface.create_for_instances 'Klass' do
        def one; 1 end
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
      include MrubySandbox::Sandbox::LocalObject
    end

    MrubySandbox::Sandbox::WorldInterface.create_for_instances 'Preserve' do
      def nil; nil end
      def false; false end
      def true; true end
      def int; 1 end
      def float; 1.2 end
      def string; 'string' end
      def symbol; :symbol end
      def array; [:item1, :item2] end
      def hash_obj; { key: :value } end
    end

    sandbox.inject Preserve.new, as: :preserve

    client = sandbox.evaluate(<<-CODE.strip_heredoc, __FILE__, __LINE__+1)
      class Servable
        include Sandbox::LocalObject
      end

      Sandbox::WorldInterface.create_for_instances 'Servable' do
        def nil; preserve.nil end
        def false; preserve.false end
        def true; preserve.true end
        def int; preserve.int end
        def float; preserve.float end
        def string; preserve.string end
        def symbol; preserve.symbol end
        def array; preserve.array end
        def hash_obj; preserve.hash_obj end
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
    stub_const('Safe', Module.new.extend(MrubySandbox::Sandbox::LocalObject['Safe']) )
    MrubySandbox::Sandbox::WorldInterface.create_for_object('Safe')

    sandbox.inject Safe, as: 'Object#safe'

    client = sandbox.evaluate(<<-CODE.strip_heredoc, __FILE__, __LINE__+1)
      Sandbox::WorldInterface.create_for_object 'Servable' do
        def test_eval; safe.eval end
        def test_instance_eval; safe.instance_eval end
        def test_instance_exec; safe.instance_exec end
        def test_class_eval; safe.class_eval end
        def test_class_exec; safe.class_exec end
        def test_module_eval; safe.module_eval end
        def test_module_exec; safe.module_exec end
      end

      Object.new.extend Sandbox::LocalObject['Servable']
    CODE

    expect{ client.test_eval }.to raise_error(
      WorldObject::RemoteError, "Servable.test_eval: Safe.eval: undefined")

    expect{ client.test_instance_eval }.to raise_error(
      WorldObject::RemoteError, "Servable.test_instance_eval: Safe.instance_eval: undefined")
    expect{ client.test_instance_exec }.to raise_error(
      WorldObject::RemoteError, "Servable.test_instance_exec: Safe.instance_exec: undefined")

    expect{ client.test_class_eval }.to raise_error(
      WorldObject::RemoteError, "Servable.test_class_eval: Safe.class_eval: undefined")
    expect{ client.test_class_exec }.to raise_error(
      WorldObject::RemoteError, "Servable.test_class_exec: Safe.class_exec: undefined")

    expect{ client.test_module_eval }.to raise_error(
      WorldObject::RemoteError, "Servable.test_module_eval: Safe.module_eval: undefined")
    expect{ client.test_module_exec }.to raise_error(
      WorldObject::RemoteError, "Servable.test_module_exec: Safe.module_exec: undefined")
  end
end