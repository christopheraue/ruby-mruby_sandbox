describe MrubySandbox do
  specify { expect(described_class::Client).to be PipeRpc::Client }
  specify { expect(described_class::Server).to be PipeRpc::Server }
  specify { expect(described_class::Mapper).to be PipeRpc::Mapper }
  specify { expect(described_class::BasicInterface).to be PipeRpc::BasicInterface }
end