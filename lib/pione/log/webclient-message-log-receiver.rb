module Pione
  module Log
    # `WebclientMessageLogReceiver` is a spcial message log receiver for
    # webclient.
    class WebclientMessageLogReceiver < MessageLogReceiver
      include DRbUndumped

      def initialize(websocket_manager)
        @websocket_manager = websocket_manager
      end

      def receive(message, level, header, color, job_id)
        data = {content: message, level: level, header: header, color: color}
        Global.io.push("message-log", data, to: @websocket_manager.find(job_id));
      end
    end
  end
end
