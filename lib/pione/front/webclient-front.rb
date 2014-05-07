module Pione
  module Front
    # WebclientFront is a front interface for +pione-webclient+ command.
    class WebclientFront < BasicFront
      # Create a new front.
      def initialize(cmd)
        super(cmd, Global.webclient_front_port_range)
      end

      def request_interactive_operation(session_id, type, data)
        unless Global.interactive_operation_manager
          raise Webclient::InteractiveOperationFailure.new("Interactive operation manager not found.")
        end

        return Global.interactive_operation_manager.request(session_id, type, data)
      end
    end
  end
end
