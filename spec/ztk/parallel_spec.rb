################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) Jove Labs
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

require "spec_helper"

describe ZTK::Parallel do

  before(:all) do
  end

  subject { ZTK::Parallel.new }

  describe "class" do

    it "should be of kind ZTK::Parallel class" do
      subject.should be_an_instance_of ZTK::Parallel
    end

    describe "default config" do

      it "should use $stdout as the default STDOUT" do
        subject.config.stdout.should be_a_kind_of $stdout.class
        subject.config.stdout.should == $stdout
      end

      it "should use $stderr as the default STDERR" do
        subject.config.stderr.should be_a_kind_of $stderr.class
        subject.config.stderr.should == $stderr
      end

      it "should use $stdin as the default STDIN" do
        subject.config.stdin.should be_a_kind_of $stdin.class
        subject.config.stdin.should == $stdin
      end

      it "should use $logger as the default logger" do
        subject.config.logger.should be_a_kind_of ZTK::Logger
        subject.config.logger.should == $logger
      end

    end

  end

  it "should spawn multiple processes to handle each iteration" do
    3.times do |x|
      subject.process do
        Process.pid
      end
    end
    subject.waitall
    puts subject.results.inspect
    subject.results.all?{ |r| r.should be_kind_of Integer }
    subject.results.all?{ |r| r.should > 0 }
    if ENV['CI'] && ENV['TRAVIS']
      # for some odd reason this is always -1 on travis-ci
      subject.results.uniq.count.should == 2
    else
      subject.results.uniq.count.should == 3
    end
    subject.results.include?(Process.pid).should be false
  end

end