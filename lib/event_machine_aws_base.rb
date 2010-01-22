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

require 'monkey_patches/http_client2'

module EventMachineAWS
  def self.async_http_request(req_hash, parser_class, &block)
    # TODO: implement connection pooling
    conn = EM::Protocols::HttpClient2.connect(
      :host => req_hash[:server], 
      :port => req_hash[:port],
      :ssl =>  (req_hash[:protocol] == 'https')
    )
    req = case req_hash[:request]
      when Net::HTTP::Get
        conn.get(req_hash[:request].path)
      when Net::HTTP::Post
        
        http_req = req_hash[:request]
        conn.post({
          :verb => 'POST',
          :uri => http_req.path,
          :body => http_req.body,
          :host => req_hash[:host],
          :content_type => 'application/x-www-form-urlencoded'
        })
    end
    
    
    req.callback do |response|
      parser = parser_class.new
      parser.parse(req.content)
      block.call(parser.result)
    end
    #TODO:  req.errback do |err|
  end
  
  # Format array of items into Amazons handy hash ('?' is a place holder):
  #
  #  amazonize_list('Item', ['a', 'b', 'c']) =>
  #    { 'Item.1' => 'a', 'Item.2' => 'b', 'Item.3' => 'c' }
  #
  #  amazonize_list('Item.?.instance', ['a', 'c']) #=>
  #    { 'Item.1.instance' => 'a', 'Item.2.instance' => 'c' }
  #
  #  amazonize_list(['Item.?.Name', 'Item.?.Value'], {'A' => 'a', 'B' => 'b'}) #=>
  #    { 'Item.1.Name' => 'A', 'Item.1.Value' => 'a',
  #      'Item.2.Name' => 'B', 'Item.2.Value' => 'b'  }
  #
  #  amazonize_list(['Item.?.Name', 'Item.?.Value'], [['A','a'], ['B','b']]) #=>
  #    { 'Item.1.Name' => 'A', 'Item.1.Value' => 'a',
  #      'Item.2.Name' => 'B', 'Item.2.Value' => 'b'  }
  #
  def self.amazonize_list(masks, list) #:nodoc:
    groups = {}
    list.to_a.each_with_index do |list_item, i|
      masks.to_a.each_with_index do |mask, mask_idx|
        key = mask[/\?/] ? mask.dup : mask.dup + '.?'
        key.gsub!('?', (i+1).to_s)
        groups[key] = list_item.to_a[mask_idx]
      end
    end
    groups
  end
end
