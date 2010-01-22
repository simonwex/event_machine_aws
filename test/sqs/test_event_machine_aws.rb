# Copyright (c) 2010 Simon C. Wex
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

$: << File.expand_path(File.dirname(__FILE__) + "/../../")
require 'test/test_helper'

# TODO: Work out the paths... this is gross?
require 'event_machine_aws/sqs'

class TestEventMachineSqs < Test::Unit::TestCase
  
  def setup
    $stdout.sync = true
    @sqs = EventMachineAws::Sqs.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key, :logger => Logger.new('/dev/null'))
  end
  
  
  def test_list_queues
    EM.run do
      @sqs.queue('TestEventMachineSqs_1') do |new_queue|
        @sqs.queues('TestEventMachineSqs_1') do |queues|
          assert_equal 1, queues.size
          EM.stop
        end  
      end
    end
  end

  def test_find_queue
    EM.run do
      @sqs.queue('TestEventMachineSqs_1') do |queue|
        assert_equal queue.name, 'TestEventMachineSqs_1'
        EM.stop
      end
    end
  end
  
  def test_send_receive_and_delete_message
    EM.run do
      @sqs.queue('TestEventMachineSqs_test_send_message') do |queue|
        queue.send_message('this is a test of the emergency broadcast system') do |msg|
          EM::add_timer(2) do
            queue.receive_messages(:max => 10) do |message|
              assert_equal 'this is a test of the emergency broadcast system', message.to_s
              message.delete do |status|
                message_received = false
                queue.receive_messages(
                  :max => 10, 
                  :finalizer => Proc.new do
                    assert !message_received
                    EM.stop
                  end
                ) do |message|
                  # This should not be run, because we should have deleted any messages.
                  message_received = true
                end
              end
            end
          end
        end
      end
    end
  end
  
  def test_create_missing_queue
    queue_name = 'a_queue_that_is_not_a_queue_yet'
    EM.run do
      @sqs.delete_queue(queue_name) do |deleted|
        @sqs.queue(queue_name, false) do |missing_queue|
          assert_nil missing_queue
          @sqs.queue(queue_name) do |new_queue|
            assert_equal new_queue.name, queue_name
            EM.stop
          end
        end
      end
    end
  end
end
