describe MrubySandbox::Client do
  subject { described_class }
  it { is_expected.to be PipeRpc::Client }
end