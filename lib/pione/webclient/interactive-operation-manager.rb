module Pione
  module Webclient
    class InteractiveOperationManager
      def initialize
        @lock = Mutex.new
        @table = Hash.new
        @result = Hash.new
        @thread = Hash.new
      end

      def request(session_id, type, data)
        get_operation_lock(session_id).lock

        case type
        when :page
          req = Global.job_queue.find_request(session_id)
          req.interactive_front = data[:front]
          Global.io.push("interactive-page", {url: "interactive/%s/index.html" % session_id}, :to => session_id)
        when :dialog
          # notify start of interactive operation to browser
          Global.io.push("interactive-dialog", {content: data[:content], script: data[:script]}, :to => session_id)
        end

        # wait to finish the operation
        @thread[session_id] = Thread.current
        Thread.stop

        # clear interactive front uri
        if req
          req.interactive_front = nil
        end

        # return the result
        return @result.delete(session_id)
      end

      def finish(session_id, result)
        @result[session_id] = result
        thread = @thread.delete(session_id)
        thread.wakeup

        # notify interactive operation has finshed
        Global.io.push("finish-interactive-operation", {}, :to => session_id)
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
