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

require 'time'

class EventMachine::Protocols::HttpClient2
  class Request
    attr_reader :conn
    attr_accessor :headers
    
    def headers
      @headers ||= {}
    end
    
    alias :connection :conn 
    
    # There are print outs peppered through http client2 that get pretty annoying
    def p(string);end
  
    # Allow custom headers and authorization
    def send_request
  		az = @args[:authorization] and az = "Authorization: #{az}\r\n"
      body = @args.delete(:body)
      headers = @args.delete(:headers)
      body.strip! if body
      content_type = @args[:content_type]
  		r = [
  		  	"#{@args[:verb]} #{@args[:uri]} HTTP/#{@args[:version] || "1.1"}\r\n",
    			"Host: #{@args[:host_header] || "_"}\r\n",
    			az || "",
    			"Content-Length: #{body.nil? ? 0 : body.size}\r\n",
    			"Date: #{Time.now.httpdate}\r\n",
    			content_type.nil? ? "" : "Content-Type: #{content_type}\r\n"
    	] + 
      (headers.nil? ? [] : headers.keys.map{|key| "#{key}: #{headers[key]}\r\n"}) +
      ["\r\n", body]
      
  		@conn.send_data(r.join)
  	end
  end
	
	def put(args)
		if args.is_a?(String)
			args = {:uri=>args}
		end
		args[:verb] = "PUT"
		request args
	end
end
