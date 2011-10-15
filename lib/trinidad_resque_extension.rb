require 'uri'
require 'rake'
require 'resque'
require 'resque/tasks'
require 'resque/server'

require 'trinidad_resque_extension/ext/resque'

require 'trinidad_resque_extension/version'
require 'trinidad_resque_extension/resque_lifecycle_listener'
require 'trinidad_resque_extension/resque_extension'
