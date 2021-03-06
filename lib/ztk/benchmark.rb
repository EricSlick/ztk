require 'benchmark'

module ZTK

  # Benchmark Error Class
  #
  # @author Zachary Patten <zachary AT jovelabs DOT com>
  class BenchmarkError < Error; end

  # Benchmark Class
  #
  # This class contains a benchmarking tool which doubles to supply indications
  # of activity to the console user during long running tasks.
  #
  # It can be run strictly for benchmarking (the default) or if supplied with
  # the appropriate options it will display output to the user while
  # benchmarking the supplied block.
  #
  # *example code*:
  #
  #     message = "I wonder how long this will take?"
  #     mark = " ...looks like it took %0.4f seconds!"
  #     ZTK::Benchmark.bench(:message => message, :mark => mark) do
  #       sleep(1.5)
  #     end
  #
  # *pry output*:
  #
  #     [1] pry(main)> message = "I wonder how long this will take?"
  #     => "I wonder how long this will take?"
  #     [2] pry(main)> mark = " ...looks like it took %0.4f seconds!"
  #     => " ...looks like it took %0.4f seconds!"
  #     [3] pry(main)> ZTK::Benchmark.bench(:message => message, :mark => mark) do
  #     [3] pry(main)*   sleep(1.5)
  #     [3] pry(main)* end
  #     I wonder how long this will take?  ...looks like it took 1.5229 seconds!
  #     => 1.522871547
  #
  # @author Zachary Patten <zachary AT jovelabs DOT com>
  class Benchmark

    class << self

      # Benchmark the supplied block.
      #
      # If *message* and *mark* options are used, then the *message* text will
      # be displayed to the user.  The the supplied *block* is yielded inside
      # a *ZTK::Spinner.spin* call.  This will provide the spinning cursor while
      # the block executes.  It is advisable to not have output sent to the
      # console during this period.
      #
      # Once the block finishes executing, the *mark* text is displayed with
      # the benchmark supplied to it as a sprintf option.  One could use "%0.4f"
      # in a *String* for example to get the benchmark time embedded in it
      #
      # @see Kernel#sprintf
      #
      # @param [Hash] options Configuration options hash.
      # @option options [String] :message The *String* to be displayed to the
      #   user before the block is yielded.
      # @option options [String] :mark The *String* to be displayed to the user
      #   after the block is yielded.  This *String* should have an *sprintf*
      #   floating point macro in it if the benchmark is desired to be embedded
      #   in the given *String*.
      # @option options [Boolean] :use_spinner (true) Whether or not to use the
      #   ZTK::Spinner while benchmarking.
      #
      # @yield Block should execute the tasks to be benchmarked.
      # @yieldreturn [Object] The return value of the block is ignored.
      # @return [Float] The benchmark time.
      #
      def bench(options={}, &block)
        options = Base.build_config({
          :use_spinner => true
        }, options)

        !block_given? and Base.log_and_raise(options.ui.logger, BenchmarkError, "You must supply a block!")

        if (!options.message.nil? && !options.message.empty?)
          options.ui.stdout.print(options.message)
          options.ui.logger.info { options.message.strip }
        end

        benchmark = ::Benchmark.realtime do
          if options.use_spinner
            ZTK::Spinner.spin(options) do
              yield
            end
          else
            yield
          end
        end

        if (!options.mark.nil? && !options.mark.empty?)
          options.ui.stdout.print(options.mark % benchmark)
          options.ui.logger.info { options.mark.strip % benchmark }
        end

        benchmark
      end

    end

  end

end
