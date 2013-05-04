################################################################################
#
#      Author: Zachary Patten <zachary AT jovelabs DOT com>
#   Copyright: Copyright (c) Zachary Patten
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

module ZTK::DSL::Core

  # @author Zachary Patten <zachary AT jovelabs DOT com>
  # @api private
  module Dataset

    def self.included(base)
      base.class_eval do
        base.send(:extend, ZTK::DSL::Core::Dataset::ClassMethods)
      end
    end

    # @author Zachary Patten <zachary AT jovelabs DOT com>
    module ClassMethods

      def dataset
        klass = self.to_s.underscore.to_sym
        @@dataset ||= {}
        if @@dataset.key?(klass)
          @@dataset[klass]
        else
          @@dataset[klass] ||= []
        end
      end

      def purge
        @@dataset = nil
      end

      def id
        @@id ||= 0
        (@@id += 1)
      end

    end

  end
end
