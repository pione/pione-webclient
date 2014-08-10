module Pione
  module Webclient
    # `JobQueue` is a queue of process jobs.
    class JobQueue
      attr_reader :fetch_thread
      attr_reader :process_thread
      attr_accessor :message_log_receiver

      def initialize(model, websocket_manager)
        @model = model
        @jobs = Set.new
        @pid = Hash.new
        @queue = Queue.new
        @queue_max_size = Global.job_queue_max
        @message_log_receiver = nil
        @websocket_manager = websocket_manager

        # run loops
        start
      end

      def active?(job_id)
        @jobs.include?(job_id)
      end

      # Add the request into the queue. It constraints max job size, so raise a
      # busy error if the request is not accepted.
      #
      # @param job_id [String]
      #    job ID
      # @param ppg [String]
      #    URL of PPG file
      # @param files [Array<String>]
      #    list of URL of input files
      # @return [void]
      def request(job)
        if @queue.size > @queue_max_size
          # server is busy
          update_status(job.id, name: "BUSY")
        else
          # cancel if there exists the session's old request already
          cancel(job) if active?(job.id)

          # register the request
          @jobs.add(job.id)
          @queue.push(job)

          # send an "ACCEPTED" message
          update_status(job.id, name: "ACCEPTED")
        end
      end

      # Cancel the request.
      #
      # @param [String] job_id
      #   job ID
      def cancel(job)
        if @jobs.include?(job.id)
          # deactivate the request
          @jobs.delete(job.id)

          # kill processing PID
          if @pid[job.id]
            Process.kill(:TERM, @pid[job.id])
          end

          # push status message
          update_status(job.id, name: "CANCELED")

          return true
        else
          return false
        end
      end

      # Return the zip file location for the UUID.
      #
      # @param uuid [String]
      #   UUID
      # @return [Location::DataLocation]
      #   zip location
      def result(uuid)
        @result[uuid]
      end

      private

      # Update status. This notify server status to clients that joins the job.
      #
      # @param [String] job_id
      #   job ID
      # @param [Hash] data
      #   status data
      # @return [void]
      def update_status(job_id, data)
        Global.io.push("status", data.merge(job_id: job_id), to: @websocket_manager.find(job_id))
      end

      # Run a loop for processing jobs.
      #
      # @return [void]
      def start
        @thread = Thread.new do
          # pop a request
          while (job = @queue.pop) do
            if job.exist?
              # process the request
              result_type = process(job)
              archive_result(job, result_type)

              # push status message
              update_status(job.id, name: "COMPLETED")
            end

            # remove the request
            @jobs.delete(job.id)
          end
        end
      end

      # Process the request.
      #
      # @param req [Webclient::Request]
      #   processing request
      # @return [Symbol]
      #   :succeeded or :failed
      def process(job)
        # push status message
        update_status(job.id, name: "PROCESSING") if active?(job.id)

        # spawn `pione-client`
        spawner = spawn_pione_client(job)
        @pid[job.id] = spawner.pid

        # wait to finish processing
        if thread = spawner.thread
          status = thread.value

          # check the process result
          if status.kind_of?(Process::Status) and not(status.success?)
            update_status(job.id, name: "PROCESS_ERROR") if active?(job.id)
            return :failed
          end
        end

        return :succeeded
      rescue Object => e
        msg = "An error has raised when pione-webclient was processing a job for %s : %s"
        msg = msg % [job.id, e.message]
        Log::SystemLog.error(msg)
        update_status(job.id, name: "PROCESS_ERROR")
        return :failed
      ensure
        @pid.delete(job.id)
      end

      # Spawn `pione-client` for the request.
      #
      # @return [Command::Spawner]
      #   spawned process
      def spawn_pione_client(job)
        # bundle exec pione-client
        spawner = Command::Spawner.new(@model, "pione-client")

        # options
        if job.input_location.exist?
          spawner.option("--input", job.input_location.address)
        end
        spawner.option("--base", job.base_location.address)
        spawner.option("--parent-front", @model[:front].uri)
        # if Global.presence_notification_addresses
        #   Global.presence_notification_addresses.each do |address|
        #     spawner.option("--presence-notification-address", address.to_s)
        #   end
        # end
        spawner.option("--stand-alone") if Global.stand_alone

        # session
        spawner.option("--request-from", @model[:front].uri)
        spawner.option("--session-id", job.id)

        spawner.option("--client-ui", "Browser")

        # arguements
        spawner.option((job.ppg_location + job.ppg_filename).address)

        spawner.spawn
      end

      def archive_result(job, result_type)
        # push status message
        update_status(job.id, name: "ARCHIVING")

        # make xes logs
        if result_type == :succeeded
          make_xes_logs(job)
        end

        # make the result zip file
        uuid = Util::UUID.generate
        filename = generate_result_filename(result_type)
        job.make_zip(filename)
        Global.io.push(:result, {job_id: job.id, filename: filename}, :to => @websocket_manager.find(job.id))
      end

      def generate_result_filename(result_type)
        if result_type == :succeeded
          return Time.now.strftime("pione-%Y%m%d%H%M%S.zip")
        else
          return Time.now.strftime("pione-" + result_type.to_s + "-%Y%m%d%H%M%S.zip")
        end
      end

      def make_xes_logs(job)
        # xes log
        formatter = Log::ProcessLog[:xes]
        log = formatter.read(job.base_location + "pione-process.log")
        log_id = log.keys.sort.last

        # agent.xes
        agent_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "agent_activity"))
        end
        agent_xes = log[log_id].format([agent_filter])
        (job.base_location + "pione-process-agent.xes").write(agent_xes)

        # rule.xes
        rule_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "rule_process"))
        end
        rule_xes = log[log_id].format([rule_filter])
        (job.base_location + "pione-process-rule.xes").write(rule_xes)

        # task.xes
        task_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "task_process"))
        end
        task_xes = log[log_id].format([task_filter])
        (job.base_location + "pione-process-task.xes").write(task_xes)
      end
    end
  end
end
