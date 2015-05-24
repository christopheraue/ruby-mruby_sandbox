describe "The sandbox" do
  subject(:mirb_sandbox) { Sandbox.new }
  subject(:sandbox) { PipeRpc::Client.new(socket: mirb_sandbox.socket) }

  it "can be cleared" do
    expect(sandbox.clear).to be true
  end

  it "can execute trusted code" do
    expect(sandbox.eval_trusted('5*8')).to be 40
  end

  it "can execute untrusted code" do
    expect(sandbox.eval_untrusted('5+8')).to be 13
  end

  describe "The environment for untrusted code" do
    it "does not have access to some constants" do
      expect{ sandbox.eval_untrusted('Sandbox')     }.to raise_error('uninitialized constant Untrusted::Sandbox')
      expect{ sandbox.eval_untrusted('IO')          }.to raise_error('uninitialized constant Untrusted::IO')
      expect{ sandbox.eval_untrusted('PipeRpc')     }.to raise_error('uninitialized constant Untrusted::PipeRpc')
      expect{ sandbox.eval_untrusted('Trusted')     }.to raise_error('uninitialized constant Untrusted::Trusted')
      expect{ sandbox.eval_untrusted('GC')          }.to raise_error('uninitialized constant Untrusted::GC')
      expect{ sandbox.eval_untrusted('ObjectSpace') }.to raise_error('uninitialized constant Untrusted::ObjectSpace')
    end

    it 'can be send code in multiple calls' do
      sandbox.eval_untrusted(<<-CODE)
        def bla(v = nil)
          v.nil? ? @bla : @bla = v
        end
      CODE

      sandbox.eval_untrusted(<<-CODE)
        bla 'const'
      CODE

      expect(sandbox.eval_untrusted('bla')).to eq 'const'
    end
  end

  describe "The environment of trusted code" do
    context "when untrusted code has already been loaded" do
      before { sandbox.eval_untrusted(<<-CODE) }
        def meth
          'result'
        end

        module Mod; end

        class Klass
          def meth
            'klass meth'
          end
        end
      CODE

      it "has access to already evaled untrusted code" do
        expect(sandbox.eval_trusted('untrusted::Mod')).to match /::Mod$/
        expect(sandbox.eval_trusted('untrusted::Klass')).to match /::Klass/
        expect(sandbox.eval_trusted('untrusted::Klass.new.meth')).to eq 'klass meth'
        expect(sandbox.eval_trusted('untrusted.meth')).to eq 'result'
      end
    end

    it "can create a receiver for requests" do
      sandbox.eval_trusted(<<-CODE)
        class Receiver
          def multiply(a, b)
            a * b
          end
        end
        export(Receiver.new, as: :receiver)
      CODE

      client = PipeRpc::Client.new(socket: mirb_sandbox.socket, receiver: :receiver)
      expect(client.multiply(5, 9)).to be 45
      expect{ client.clear }.to raise_error(NoMethodError)
    end

    it "can summon a client to talk to a server" do
      class Receiver
        def exp(a, b)
          a ** b
        end
      end
      server = PipeRpc::Server.new(socket: mirb_sandbox.socket, receiver: { math: Receiver.new })
      sandbox = PipeRpc::Client.new(server: server)

      expect(sandbox.eval_trusted 'client_for(:math).exp(2,8)').to be 256
      expect{ sandbox.eval_trusted 'client_for(:math).exp' }.to raise_error(ArgumentError)
    end
  end
end