module Pione
  module Front
    # WebclientFront is a front interface for +pione-webclient+ command.
    class WebclientFront < BasicFront
      # Create a new front.
      def initialize(cmd)
        super(cmd, Global.webclient_front_port_range)
      end
    end
  end
end
