################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.net>
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

describe ZTK::DSL do

  subject {
    class DSLTest < ZTK::DSL::Base
    end

    DSLTest.new
  }

  before(:all) do
    $stdout = File.open("/dev/null", "w")
    $stderr = File.open("/dev/null", "w")
    $stdin = File.open("/dev/null", "r")
  end

  describe "class" do

    it "should be an instance of ZTK::DSL" do
      subject.should be_an_instance_of DSLTest
    end

    describe "default config" do

      # it "should use $stdout as the default" do
      #   subject.config.stdout.should be_a_kind_of $stdout.class
      #   subject.config.stdout.should == $stdout
      # end

      # it "should use $stderr as the default" do
      #   subject.config.stderr.should be_a_kind_of $stderr.class
      #   subject.config.stderr.should == $stderr
      # end

      # it "should use $stdin as the default" do
      #   subject.config.stdin.should be_a_kind_of $stdin.class
      #   subject.config.stdin.should == $stdin
      # end

      # it "should use $logger as the default" do
      #   subject.config.logger.should be_a_kind_of ZTK::Logger
      #   subject.config.logger.should == $logger
      # end

    end

  end

  describe "attribute" do

    it "should allow setting of an attribute via a block" do
      data = "Hello World @ #{Time.now.utc}"
      class DSLTest < ZTK::DSL::Base
        attribute :name
      end

      dsl_test = DSLTest.new do
        name "#{data}"
      end

      dsl_test.name.should == data
    end

    it "should allow setting of an attribute directly" do
      data = "Hello World @ #{Time.now.utc}"
      class DSLTest < ZTK::DSL::Base
        attribute :name
      end

      dsl_test = DSLTest.new
      dsl_test.name ="#{data}"

      dsl_test.name.should == data
    end

    it "should throw an exception when setting an invalid attribute" do
      data = "Hello World @ #{Time.now.utc}"
      class DSLTest < ZTK::DSL::Base
        attribute :name
      end

      lambda {
        dsl_test = DSLTest.new do
          thing "#{data}"
        end
      }.should raise_error
    end

  end

  describe "nesting" do

    it "should allow nesting of DSL classes" do
      data = "Hello World @ #{Time.now.utc}"
      class DSLTestA < ZTK::DSL::Base
        has_many :dsl_test_b
        attribute :name
      end

      class DSLTestB < ZTK::DSL::Base
        attribute :name
      end

      dsl_test = DSLTest.new do
        name "#{data}"
      end

      dsl_test.name.should == data
    end

  end

end