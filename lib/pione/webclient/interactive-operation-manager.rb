module Pione
  module Webclient
    class InteractiveOperationManager
      def initialize
        @lock = Mutex.new
        @table = Hash.new
        @result = Hash.new
        @thread = Hash.new
      end

      def request(session_id, content, script)
        get_operation_lock(session_id).lock

        # notify start of interactive operation to browser
        Global.io.push(:interactive, {content: content, script: script}, :to => session_id)

        # wait to finish the operation
        @thread[session_id] = Thread.current
        Thread.stop

        # return the result
        return @result.delete(session_id)
      end

      def finish(session_id, result)
        @result[session_id] = result
        thread = @thread.delete(session_id)
        thread.wakeup
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
