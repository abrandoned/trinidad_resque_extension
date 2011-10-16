$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'trinidad'
require 'trinidad_resque_extension'
require 'redis_mock'
require 'mocha'

RSpec.configure do |config|
  config.mock_with :mocha
end
