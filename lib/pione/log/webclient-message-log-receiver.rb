module Pione
  module Log
    # `WebclientMessageLogReceiver` is a spcial message log receiver for
    # webclient.
    class WebclientMessageLogReceiver < MessageLogReceiver
      include DRbUndumped

      attr_accessor :session_id

      def initialize
        @session_id = nil
      end

      def receive(message, level, header, color)
        if @session_id
          data = {content: message, level: level, header: header, color: color}
          Global.io.push("message-log", data, to: @session_id);
        end
      end
    end
  end
end
