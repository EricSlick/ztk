require 'pty'

module ZTK

  # PTY Error Class
  #
  # @author Zachary Patten <zachary AT jovelabs DOT com>
  class PTYError < Error; end

  # Ruby PTY Class Wrapper
  #
  # Wraps the Ruby PTY class, providing better functionality.
  #
  # @author Zachary Patten <zachary AT jovelabs DOT com>
  class PTY

    class << self

      # Spawns a ruby-based PTY.
      #
      # @param [Array] args An argument splat to be passed to PTY::spawn
      #
      # @return [Object] Returns the $? object.
      def spawn(*args, &block)

        if block_given?
          ::PTY.spawn(*args) do |reader, writer, pid|
            begin
              yield(reader, writer, pid)
            rescue Errno::EIO
            ensure
              ::Process.wait(pid)
            end
          end
        else
          reader, writer, pid = ::PTY.spawn(*args)
        end

        [reader, writer, pid]
      end

    end

  end

end