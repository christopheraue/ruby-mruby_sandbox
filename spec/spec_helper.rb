require 'bundler/setup'
require 'mruby_sandbox'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end