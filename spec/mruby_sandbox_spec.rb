describe MrubySandbox do
  specify { expect(described_class::Client).to be PipeRpc::Client }
  specify { expect(described_class::ClientWrapper).to be PipeRpc::ClientWrapper }
  specify { expect(described_class::Server).to be PipeRpc::Server }
  specify { expect(described_class::SubjectServer).to be PipeRpc::SubjectServer }
end