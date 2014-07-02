module Pione
  module Webclient
    module Timestamp
      # Parse the timestamp string as a date object. This assumes the timestamp
      # is ISO8601 format.
      #
      # @return [Time]
      #   timestamp
      def self.parse(string)
        if string
          Time.iso8601(string)
        end
      end

      # Dump the timestamp as a string.
      #
      # @parma time [Time] the timestamp
      # @return [String]
      #   a string
      def self.dump(time)
        if time
          time.iso8601
        end
      end
    end
  end
end
