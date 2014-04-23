module Pione
  module Webclient
    class WebclientError < StandardError; end

    class InteractiveOperationFailure < WebclientError
    end
  end
end
