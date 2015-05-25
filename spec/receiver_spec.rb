describe MrubySandbox::Receiver do
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