describe MrubySandbox::Server do
  subject(:klass) { described_class }
  its(:superclass) { is_expected.to be PipeRpc::Server }
end