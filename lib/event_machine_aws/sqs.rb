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

require 'right_aws'
require 'eventmachine'
require 'event_machine_aws_base'

module EventMachineAws
    
  class Sqs
        
    attr_reader :interface
    
    def initialize(aws_access_key_id = nil, aws_secret_access_key = nil, params={})
      @interface = RightAws::SqsGen2Interface.new(aws_access_key_id, aws_secret_access_key, params)
    end
    
    # Retrieves a list of queues.
    # Returns an +array+ of +Queue+ instances.
    #
    # EventMachineAWS::Sqs.queues #=> array of queues
    #
    def queues(prefix = nil, &block)
      req_hash = @interface.generate_request('ListQueues', 'QueueNamePrefix' => prefix)
      EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsListQueuesParser) do |result|
        block.call(result.map{|name| Queue.new(self, name)})
      end
    end
    
    # Returns Queue instance by queue name. 
    # If the queue does not exist at Amazon SQS and +create+ is true, the method creates it.
    #
    #  EventMachineAWS::Sqs.queue('my_awesome_queue') #=> #<EventMachineAWS::Sqs::Queue:0xb7b626e4 ... >
    #
    def queue(queue_name, create = true, visibility = nil, &block)
      queues(queue_name) do |queues|
        queue = queues.map do |queue|
          queue.name == queue_name ? queue : nil
        end.compact.first
        if queue
          block.call(queue)
        else
          if queue.nil?
            if create
              req_hash = @interface.generate_request(
                'CreateQueue', 
                'QueueName' => queue_name,
                'DefaultVisibilityTimeout' => RightAws::SqsGen2Interface::DEFAULT_VISIBILITY_TIMEOUT
              )
          
              EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsCreateQueueParser) do |result|
                #TODO: <?xml version=\"1.0\"?>\n<ErrorResponse xmlns=\"http://queue.amazonaws.com/doc/2008-01-01/\"><Error><Type>Sender</Type><Code>AWS.SimpleQueueService.QueueDeletedRecently</Code><Message>You must wait 60 seconds after deleting a queue before you can create another with the same name.</Message><Detail/></Error><RequestId>5c70ccd9-d3a0-4f90-9161-8c50ee0fc4e8</RequestId></ErrorResponse>"
                block.call(Queue.new(self, result))
              end
            else
              block.call(nil)
            end
          else
            block.call(queue)
          end
        end
      end
    end
    
    def delete_queue(queue_name, &block)
      queue(queue_name, false) do |queue|
        if !queue.nil?
          req_hash = @interface.generate_request('DeleteQueue', :queue_url => queue.url)
          EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsStatusParser) do |result|
            block.call(result)
          end
        else
          block.call(nil)
        end
      end
    end
    
    def delete_message(queue_or_queue_url, receipt_handle)
      queue_or_queue_url = queue_or_queue_url.url if queue_or_queue_url.is_a?(Queue)
      req_hash = @interface.generate_request(
        'DeleteMessage', 
        'ReceiptHandle' => receipt_handle, 
        :queue_url  => queue_or_queue_url
      )
      EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsStatusParser) do |result|
        yield result if block_given?
      end
    end
    
    class Message
      attr_reader   :queue, :id, :body, :visibility
      attr_accessor :sent_at, :received_at, :send_checksum, :receive_checksum
      
      
      #(self, entry['MessageId'], entry['ReceiptHandle'], entry['Body'], visibility_timeout, entry['Attributes'])
      def initialize(queue, id = nil, body = nil, visibility = nil, receipt_handle = nil, attributes = {})
        @attributes     = attributes
        @receipt_handle = receipt_handle
        @queue          = queue
        @id             = id
        @body           = body
        @visibility     = visibility
        @sent_at        = nil
        @received_at    = nil
      end
      
      # Returns +Message+ instance body.
      def to_s
        @body
      end
            
      # Removes message from queue. 
      # Returns +true+.
      def delete(&block)
        # TODO: Better error raising
        raise 'No Receipt Handle' unless @receipt_handle
        @queue.sqs.delete_message(@queue.url, @receipt_handle, &block)
      end
    end
    
    class Queue
      
      attr_reader :name, :url, :sqs
      
      def initialize(sqs, url)
        @sqs  = sqs
        @url  = url
        @name = queue_name_from_url(url)
      end
      
      def send_message(message, &block)
        message = message.to_s

        req_hash = @sqs.interface.generate_post_request('SendMessage', :message  => message, :queue_url => @url)
        
        EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsSendMessagesParser) do |result|
          msg = Message.new(self, result['MessageId'], nil, message)
          msg.send_checksum = result['MD5OfMessageBody']
          msg.sent_at = Time.now
          block.call(msg)
        end
      end
      
      def receive_messages(args = {}, &block)
        if args[:visibility_timeout].nil?
          args[:visibility_timeout] = RightAws::SqsGen2Interface::DEFAULT_VISIBILITY_TIMEOUT
        end
        
        params = EventMachineAWS.amazonize_list('AttributeName', args[:attributes].to_a)
        params.merge!(
          'MaxNumberOfMessages' => args[:max] || 10,
          'VisibilityTimeout'   => args[:visibility_timeout] || RightAws::SqsGen2Interface::DEFAULT_VISIBILITY_TIMEOUT,
          :queue_url            => @url
        )
        req_hash = @sqs.interface.generate_post_request('ReceiveMessage', params)
        EventMachineAWS.async_http_request(req_hash, RightAws::SqsGen2Interface::SqsReceiveMessageParser) do |list|
          list.each_with_index do |entry, i|
            msg = Message.new(self, entry['MessageId'], entry['Body'], params['VisibilityTimeout'], entry['ReceiptHandle'], entry['Attributes'])
            msg.received_at = Time.now 
            msg.receive_checksum = entry['MD5OfBody']
            block.call(msg)
          end
          
          if args[:finalizer]
            args[:finalizer].call
          end
        end
      end
      
    protected  

      def queue_name_from_url(url)
        url[/[^\/]*$/]
      end
    end
  end
end
