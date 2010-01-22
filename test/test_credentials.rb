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

class TestCredentials

  @@aws_access_key_id = nil 
  @@aws_secret_access_key = nil 
  @@account_number = nil

  def self.aws_access_key_id
    @@aws_access_key_id
  end
  def self.aws_access_key_id=(newval)
    @@aws_access_key_id = newval
  end
  def self.account_number
    @@account_number
  end
  def self.account_number=(newval)
    @@account_number = newval
  end
  def self.aws_secret_access_key
    @@aws_secret_access_key
  end
  def self.aws_secret_access_key=(newval)
    @@aws_secret_access_key = newval
  end

  def self.get_credentials
    Dir.chdir do
      begin
        load("#{File.expand_path('~/.event_machine_aws/testcredentials')}")
      rescue Exception => e
        puts "Couldn't load testcredentials.rb from ~/.event_machine_aws: #{e.message}"
      end
    end
  end
end
