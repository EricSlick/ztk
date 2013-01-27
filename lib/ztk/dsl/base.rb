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

# @author Zachary Patten <zachary@jovelabs.net>
module ZTK::DSL

  class Base
    include(ZTK::DSL::Core)

    # class_attribute :model_attributes

    attribute :id

    def self.inherited(base)
      puts("inherited(#{base})")
      base.send(:extend, ZTK::DSL::Base::ClassMethods)
    end

    def self.included(base)
      puts("included(#{base})")
    end

    def self.extended(base)
      puts("extended(#{base})")
    end

    def initialize(&block)
      self.id = self.class.id
      self.class.dataset << self
      block_given? and ((block.arity < 1) ? instance_eval(&block) : block.call(self))
    end

    def inspect
      klass = self.class.to_s.downcase.to_sym
      details = Array.new
      details << "klass=#{klass.inspect}"
      details << "attributes=#{attributes.inspect}" if attributes.count > 0
      details << "has_many_references=#{@has_many_references.inspect}" if @has_many_references
      details << "belongs_to_references=#{@belongs_to_references.inspect}" if @belongs_to_references
      "#<#{self.class.to_s}:#{self.id} #{details.join(', ')}>"
    end

    module ClassMethods


      def inspect
        klass = self.to_s.downcase.to_sym
        details = Array.new
        details << "klass=#{klass.inspect}"
        details << "count=#{self.all.count}" if self.all.count > 0
        "#<#{self.class.to_s}:#{self.id} #{details.join(', ')}>"
      end

    end

  end

end
