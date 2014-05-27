module Pione
  module Front
    # WebclientFront is a front interface for +pione-webclient+ command.
    class WebclientFront < BasicFront
      # Create a new front.
      def initialize(cmd)
        super(cmd, Global.webclient_front_port_range)
      end

      # Request an interactive operation for page rendering mode.
      #
      # @param [String] session_id
      #   session ID
      # @param [String] front_address
      #   Front URI for pione-interactive
      # @return [String]
      #   a result string of requested operation
      def request_interactive_page(session_id, front_address)
        check_interactive_operation_manager
        return Global.interactive_operation_manager.request_page(session_id, data)
      end

      # Request an interactive operation.
      #
      # @param [String] session_id
      #   session ID
      # @param [Symbol] type
      #   :page or :dialog
      # @param [Hash] data
      #   optional data
      # @return [String]
      #   a result string of requested interactive operation
      def request_interactive_operation(session_id, type, data)
        check_interactive_operation_manager
        unless Global.interactive_operation_manager
          raise Webclient::InteractiveOperationFailure.new("Interactive operation manager not found.")
        end

        # run the request
        case type
        when :page
          # page rendering mode
          return Global.interactive_operation_manager.request_page(session_id, data)
        when :dialog
          # dialog mode
          return Global.interactive_operation_manager.request_dialog(session_id, data)
        else
          # unknown operation
          raise Webclient::InteractiveOperationFailure.new(
            "The type of interactive operation is unknown: %s" % type
          )
        end
      end

      private

      # Check avaiability of interactive opration manager.
      def check_interactive_operation_manager
        unless Global.interactive_operation_manager
          raise Webclient::InteractiveOperationFailure.new("Interactive operation manager not found.")
        end
      end
    end
  end
end
