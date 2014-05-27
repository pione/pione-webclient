module Pione
  module Webclient
    # InteractiveOperationManager is a manager for interactive
    # operations. Interactive operations are mutual in a session, so this
    # manages operations races.
    class InteractiveOperationManager
      def initialize
        # lock for mutual exclusive actions of this manager
        @manager_lock = Mutex.new

        # lock table for sessions
        @session_lock_table = Hash.new

        # result table
        @result = Hash.new

        # thread table for waiting operations
        @thread = Hash.new
      end

      # Request a page rendering for showing HTML contents. This sends
      # "interactive-page" command to client by using websocket, and returns the
      # result as a string.
      #
      # @param [String] job_id
      #   job ID
      # @param [String] front_address
      #   front address of pione-interactive
      # @return [String]
      #   returned value
      def request_page(job_id, front_address)
        lock_interactive_operation(job_id)

        # find current job's request and send interactive front address to it
        req = Global.job_queue.find_request(job_id)
        req.interactive_front = front_address

        # send "interactive-page" command by websocket
        Global.job_manager.session_ids(job_id).each do |session_id|
          Global.io.push(
            "interactive-page",
            {url: "/job/%s/page/index.html" % job_id},
            :to => session_id)
        end

        # wait to finish the operation
        sleep_thread(job_id)

        # clear interactive front address
        req.interactive_front = nil

        # return the result
        return @result.delete(job_id)
      end

      # Request a dialog to show to users.
      #
      # @param [String] job_id
      #   job ID
      # @param [Hash] data
      #   request data
      # @return [String]
      #   returned value
      def request_dialog(job_id, data)
        lock_interactive_operation(job_id)

        # notify a start of interactive operation
        Global.job_manager.session_ids(job_id).each do |session_id|
          Global.io.push(
            "interactive-dialog",
            {content: data[:content], script: data[:script]},
            :to => session_id)
        end

        # wait to finish the operation
        sleep_thread(job_id)

        # return the result
        return @result.delete(job_id)
      end

      # Finish the request.
      #
      # @param [String] session_id
      #   session ID
      def finish(job_id, result)
        @result[session_id] = result
        thread = @thread.delete(session_id)
        thread.wakeup

        # notify interactive operation has finshed
        Global.job_manager.session_ids(job_id).each do |session_id|
          Global.io.push("finish-interactive-operation", {}, :to => session_id)
        end
      end

      private

      # Lock interactive operations. Interactive operations should be mutually
      # exclusive.
      #
      # @param [String] session_id
      #   session ID
      # @return [Mutex]
      #   a lock for the operation
      def lock_interactive_operation(session_id)
        operation_lock = nil

        # get the lock object
        @manager_lock.synchronize do
          @session_lock_table[session_id] ||= Mutex.new
          operation_lock = @session_lock_table[session_id]
        end

        return operation_lock.lock
      end

      # Sleep current thread until interactive operation completes. This
      # sleeping thread will wake up by #finish.
      def sleep_thread(session_id)
        @thread[session_id] = Thread.current
        Thread.stop
      end
    end
  end
end
