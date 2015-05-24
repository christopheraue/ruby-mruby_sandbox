require 'bundler/setup'
require 'pipe_rpc'
require_relative 'sandbox'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end