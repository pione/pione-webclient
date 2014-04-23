module Pione
  module Webclient
    class InteractiveOperationManager
      def initialize
        @lock = Mutex.new
        @table = Hash.new
        @result = Hash.new
      end

      def request(session_id, ui_definition)
        get_operation_lock(session_id).lock

        # notify start of interactive operation to browser
        Global.io.push(:interactive, {ui: ui_definition}, :to => session_id)

        # wait to finish the operation
        @thread[session_id] = Thread.current
        Thread.current.sleep

        # return the result
        return @result.delete(session_id)
      end

      def finish(session_id, result)
        @result[session_id] = result
        @thread[session_id].wakeup
      end

      private

      def get_operation_lock(session_id)
        operation_lock = nil

        @lock.synchronize do
          @table[session_id] ||= Mutex.new
          operation_lock = @table[session_id]
        end

        return operation_lock
      end
    end
  end
end
