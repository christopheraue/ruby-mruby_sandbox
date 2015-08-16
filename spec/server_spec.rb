describe MrubySandbox::Server do
  subject(:instance) { described_class.new }

  describe "#instance_eval" do
    subject { instance.instance_eval }
    it { is_expected.to raise_error(NoMethodError) }
  end

  describe "#instance_exec" do
    subject { instance.instance_exec }
    it { is_expected.to raise_error(NoMethodError) }
  end
end

describe "Subclass" do
  subject(:klass) do
    class Subclass < MrubySandbox::Server; end
    Subclass
  end
  subject(:instance) { klass.new }

  it { is_expected.to respond_to(:respond_to?) }

  describe "#class" do
    subject { instance.class }
    it { is_expected.to be klass }
  end

  describe "#inspect" do
    subject { instance.inspect }
    let(:id) { instance.__id__ }
    it { is_expected.to eq "#<Subclass:#{'%#016x' % id}>" }
  end

  describe "Access to constants" do
    subject { klass::Object }
    it { is_expected.to be ::Object }
  end
end