# Copyright (c) 2009 Ezra Zygmuntowicz
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require "socket"

module RedisMock
  class Server
    VERBOSE = false

    def initialize(port = 6380, &block)
      @server = TCPServer.new("127.0.0.1", port)
      @server.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
      @thread = Thread.new { run(&block) }
    end

    # Bail out of @server.accept before closing the socket. This is required
    # to avoid EADDRINUSE after a couple of iterations.
    def shutdown
      @thread.terminate if @thread
      @server.close if @server
    rescue => ex
      $stderr.puts "Error closing mock server: #{ex.message}" if VERBOSE
      $stderr.puts ex.backtrace if VERBOSE
    end

    def run
      loop do
        session = @server.accept

        begin
          while line = session.gets
            parts = Array.new(line[1..-3].to_i) do
              bytes = session.gets[1..-3].to_i
              argument = session.read(bytes)
              session.read(2) # Discard \r\n
              argument
            end

            response = yield(*parts)

            if response.nil?
              session.shutdown(Socket::SHUT_RDWR)
              break
            else
              session.write(response)
              session.write("\r\n")
            end
          end
        rescue Errno::ECONNRESET
          # Ignore client closing the connection
        end
      end
    rescue => ex
      $stderr.puts "Error running mock server: #{ex.message}" if VERBOSE
      $stderr.puts ex.backtrace if VERBOSE
    end
  end

  module Helper
    # Starts a mock Redis server in a thread on port 6380.
    #
    # The server will reply with a `+OK` to all commands, but you can
    # customize it by providing a hash. For example:
    #
    #     redis_mock(:ping => lambda { "+PONG" }) do
    #       assert_equal "PONG", Redis.new(:port => 6380).ping
    #     end
    #
    def redis_mock(replies = {})
      begin
        replies = { :port => 6380 }.merge!(replies)
        server = Server.new(replies.delete(:port)) do |command, *args|
          (replies[command.to_sym] || lambda { |*_| "+OK" }).call(*args)
        end

        sleep 0.1 # Give time for the socket to start listening.

        yield

      ensure
        server.shutdown
      end
    end
  end
end
