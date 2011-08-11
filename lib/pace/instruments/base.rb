module Pace
  module Instruments
    class Base
      def initialize(options = {})
        @options = options
      end

      # Take a single value
      def record(queue, job)
      end

      # Persist or compute values stored during interval
      def save
      end
    end
  end
end
