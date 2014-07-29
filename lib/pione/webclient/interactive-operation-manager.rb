module Pione
  module Webclient
    # InteractiveOperationManager is a manager for interactive
    # operations. Interactive operations are mutual in a session, so this
    # manages operations races.
    class InteractiveOperationManager
      def initialize
        # lock for mutual exclusive actions of this manager
        @manager_lock = Mutex.new

        # lock table for jobs
        @job_lock_table = Hash.new

        # result value table
        @result = Hash.new

        # thread table for waiting operations
        @thread = Hash.new

        # pione-interactive's front addresses
        @front = Hash.new

        # current request table
        @requests = Array.new
      end

      # Request a page rendering for showing HTML contents. This sends
      # "interactive-page" command to client by using websocket, and returns the
      # result as a string.
      #
      # @param [String] job_id
      #   job ID
      # @param [String] interaction_id
      #   interaction ID
      # @param [String] front_address
      #   front address of pione-interactive
      # @return [String]
      #   returned value
      def request_page(job_id, interaction_id, data)
        @manager_lock.synchronize do
          if known?(job_id, interaction_id)
            raise Webclient::InteractiveOperationFailure.new("The interaction exists already." % job_id)
          else
            @requests << key_of(job_id, interaction_id)
          end
        end

        # check job
        unless Workspace.new(Global.workspace_root).find_job(job_id)
          raise Webclient::InteractiveOperationFailure.new("The job is unknown: %s" % job_id)
        end

        begin
          # lock for job
          lock_interaction(job_id)

          # record the front address
          @front[key_of(job_id, interaction_id)] = data[:front_address]

          # send "interactive-page" command by websocket
          Global.io.push(
            "interaction-page",
            {url: "/interactive/%s/%s/index.html" % [job_id, interaction_id], job_id: job_id},
            :to => Global.websocket_manager.find(job_id))

          # wait to finish the operation
          sleep_thread(job_id, interaction_id)

          # return the result
          return @result.delete(key_of(job_id, interaction_id))

        ensure
          # clear informations
          @front[key_of(job_id, interaction_id)] = nil
          @requests.delete(key_of(job_id, interaction_id))
          @result.delete(key_of(job_id, interaction_id))

          # unlock for job
          unlock_interaction(job_id)
        end
      end

      # Request a dialog to show to users.
      #
      # @param [String] job_id
      #   job ID
      # @param [Hash] data
      #   request data
      # @return [String]
      #   returned value
      def request_dialog(job_id, interaction_id, data)
        lock_interactive_operation(job_id)

        # notify a start of interactive operation
        Global.io.push(
          "interactive-dialog",
          {content: data[:content], script: data[:script], job_id: job_id},
          :to => Global.websocket_manager.find(job_id))

        # wait to finish the operation
        sleep_thread(job_id)

        # return the result
        return @result.delete(key_of(job_id, interaction_id))
      end

      # Return true only if the interaction is known.
      def known?(job_id, interaction_id)
        @requests.include?(key_of(job_id, interaction_id))
      end

      # Finish the request.
      #
      # @param [String] job_id
      #   job ID
      # @param [String] interaction_id
      #   interaction ID
      # @param [String] result
      #   result value
      def operation_finish(job_id, interaction_id, result)
        @result[key_of(job_id, interaction_id)] = result
        thread = @thread.delete(key_of(job_id, interaction_id))
        thread.wakeup

        # notify interactive operation has finshed
        Global.io.push(
          "finish-interaction",
          {job_id: job_id},
          :to => Global.websocket_manager.find(job_id))
      end

      # Execute the operation 'get'.
      def operation_get(job_id, interaction_id, path, cgi_info)
        interactive_front(job_id, interaction_id).get(path, cgi_info)
      end

      # Execute the operation 'create'.
      def operation_create(job_id, interaction_id, path, content)
        content = content.to_s
        pione_interactive = interactive_front(job_id, interaction_id)
        return pione_interactive.create(path, content)
      end

      # Execute the operation 'delete'.
      def operation_delete(job_id, interaction_id, path)
        interactive_front(job_id, interaction_id).delete(path)
      end

      # Execute the operation 'list'.
      def operation_list(job_id, interaction_id, path)
        interactive_front(job_id, interaction_id).list(path)
      end

      private

      def interactive_front(job_id, interaction_id)
        if front_address = @front[key_of(job_id, interaction_id)]
          return DRb::DRbObject.new_with_uri(front_address)
        else
          return nil
        end
      end

      def key_of(job_id, interaction_id)
        "%s_%s" % [job_id, interaction_id]
      end

      # Lock interactions for job. Interaction should be mutually exclusive by
      # each job.
      #
      # @param [String] job_id
      #   session ID
      # @return [void]
      def lock_interaction(job_id)
        operation_lock = nil

        # get the lock object
        @manager_lock.synchronize do
          @job_lock_table[job_id] ||= Mutex.new
          operation_lock = @job_lock_table[job_id]
        end

        return operation_lock.lock
      end

      def unlock_interaction(job_id)
        operation_lock = nil
        @manager_lock.synchronize do
          operation_lock = @job_lock_table[job_id]
        end
        operation_lock.unlock
      end

      # Sleep current thread until interactive operation completes. This
      # sleeping thread will wake up by #finish.
      def sleep_thread(job_id, interaction_id)
        @thread[key_of(job_id, interaction_id)] = Thread.current
        Thread.stop
      end
    end
  end
end
