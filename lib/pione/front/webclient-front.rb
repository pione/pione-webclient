module Pione
  module Front
    # WebclientFront is a front interface for +pione-webclient+ command.
    class WebclientFront < BasicFront
      # Create a new front.
      def initialize(cmd)
        super(cmd, Global.webclient_front_port_range)
      end

      def request_interactive_operation(session_id, ui_definition)
        if Global.job_queue
          return Global.interactive_operation_manager.request(session_id, ui_definition)
        else
          raise InteractiveOperationFailure.new("Job queue not found.")
        end
      end
    end
  end
end
