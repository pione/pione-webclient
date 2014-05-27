module Pione
  module Webclient
    # `JobQueue` is a queue of process jobs.
    class JobQueue
      attr_reader :fetch_thread
      attr_reader :process_thread
      attr_accessor :message_log_receiver

      def initialize(model)
        @model = model
        @fetch_queue = Queue.new
        @process_queue = SizedQueue.new(Global.job_queue_max)
        @request = Hash.new
        @result = Hash.new
        @message_log_receiver = nil

        # run loops
        run_fetching
        run_processing
      end

      # Find a request object by the job ID.
      #
      # @param [String] job_id
      #   job ID
      # @return [Request]
      #   a request object
      def find_request(job_id)
        @request[job_id]
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
      def request(job_id, upload_method, ppg, files)
        if @fetch_queue.size > Global.job_queue_max
          # server is busy
          update_status(job_id, name: "BUSY")
        else
          # cancel if there exists the session's old request already
          cancel(job_id) if @request[job_id]

          # register the request
          req = Request.new(job_id, upload_method, ppg, files)
          @request[job_id] = req
          @fetch_queue.push(req)

          # send an "ACCEPTED" message
          update_status(job_id, name: "ACCEPTED") if req.active
        end
      end

      # Cancel the request.
      #
      # @param [String] job_id
      #   job ID
      def cancel(job_id)
        if @request[job_id]
          # deactivate the request
          @request[job_id].active = false
          @request.delete(session_id)

          # kill processing PID
          if @processing_request and @processing_pid and @processing_request.job_id == job_id
            Process.kill(:TERM, @processing_pid)
          end

          # push status message
          update_status(job_id, name: "CANCELED")
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
        Global.jobs.sessions(job_id) do |session_id|
          Global.io.push("status", data, to: session_id)
        end
      end

      # Run a loop for fetching source files.
      #
      # @return [void]
      def run_fetching
        @fetch_thread = Thread.new do
          loop do
            # pop a request
            req = @fetch_queue.pop

            if req.active
              begin
                fetch(req)
                @process_queue.push(req)
              rescue Object => e
                # send status
                update_status(req.job_id, name: "FETCH_ERROR") if req.active

                # clear the request
                @request.delete(req.job_id)
              end
            end
          end
        end
      end

      # Run a loop for processing jobs.
      #
      # @return [void]
      def run_processing
        @process_thread = Thread.new do
          loop do
            # pop a request
            req = @process_queue.pop

            if req.active
              # process the request
              if process(req)
                make_result_archive(req)
              end
            end

            # remove the request from request table
            @request.delete(req.job_id)
          end
        end
      end

      # Fetch source files in the request.
      def fetch(req)
        # push status message
        update_status(job_id, name: "START_FETCHING") if req.active

        # fetch source files
        req.fetch do |i, size|
          update_status(req.job_id, name: "FETCH", number: i, total: size) if req.active
        end

        # push status message
        update_status(req.job_id, name: "END_FETCHING") if req.active
      end

      # Process the request.
      #
      # @param req [Webclient::Request]
      #   processing request
      # @return [void]
      def process(req)
        @processing_request = req

        # setup message log receiver
        @message_log_receiver.job_id = req.job_id

        # push status message
        update_status(req.job_id, name: "START_PROCESSING") if req.active

        # spawn `pione-client`
        spawner = spawn_pione_client(req)
        @processing_pid = spawner.pid

        # wait to finish processing
        if thread = spawner.thread
          status = thread.value

          # check the process result
          if status.kind_of?(Process::Status) and not(status.success?)
            update_status(req.job_id, name: "PROCESS_ERROR") if req.active
            return false
          end
        end

        # process killed if the request is not active
        return false unless req.active

        # push status message
        update_status(req.job_id, name: "END_PROCESSING")

        return true
      rescue Object => e
        msg = "An error has raised when pione-webclient was processing a job for %s : %s"
        msg = msg % [req.job_id, e.message]
        Log::SystemLog.error(msg)
        update_status(job_id, name: "PROCESS_ERROR")
      ensure
        @message_log_receiver.job_id = nil
        @processing_request = nil
        @processing_pid = nil
      end

      # Spawn `pione-client` for the request.
      #
      # @return [Command::Spawner]
      #   spawned process
      def spawn_pione_client(req)
        # bundle exec pione-client
        spawner = Command::Spawner.new(@model, "pione-client")

        # options
        if req.local_input_location.exist?
          spawner.option("--input", req.local_input_location.address)
        end
        spawner.option("--output", req.base_location.address)
        spawner.option("--parent-front", @model[:front].uri)
        # if Global.presence_notification_addresses
        #   Global.presence_notification_addresses.each do |address|
        #     spawner.option("--presence-notification-address", address.to_s)
        #   end
        # end
        spawner.option("--stand-alone") if Global.stand_alone

        # session
        spawner.option("--request-from", @model[:front].uri)
        spawner.option("--job-id", req.job_id)

        spawner.option("--client-ui", "Browser")

        # arguements
        spawner.option(req.local_ppg_location.address)

        spawner.spawn
      end

      def make_result_archive(req)
        # xes log
        formatter = Log::ProcessLog[:xes]
        log = formatter.read(req.base_location + "pione-process.log")
        log_id = log.keys.sort.last

        # agent.xes
        agent_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "agent_activity"))
        end
        agent_xes = log[log_id].format([agent_filter])
        (req.base_location + "pione-process-agent.xes").write(agent_xes)

        # rule.xes
        rule_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "rule_process"))
        end
        rule_xes = log[log_id].format([rule_filter])
        (req.base_location + "pione-process-rule.xes").write(rule_xes)

        # task.xes
        task_filter = Proc.new do |trace|
          trace.attributes.include?(XES.string("pione:traceType", "task_process"))
        end
        task_xes = log[log_id].format([task_filter])
        (req.base_location + "pione-process-task.xes").write(task_xes)

        # make the result zip file
        uuid = Util::UUID.generate
        zip_location = req.make_zip
        filename = "pione-" + zip_location.mtime.strftime("%Y%m%d%H%M%S") + ".zip"
        @result[uuid] = req.make_zip
        Global.io.push(:result, {uuid: uuid, filename: filename}, :to => req.session_id)

        # push status message
        update_status(req.job_id, name: "COMPLETED")
      end
    end

    # `Request` is a class that represents processing requests.
    class Request < StructX
      member :job_id
      member :upload_method
      member :ppg
      member :files
      member :active, :default => true
      member :local_ppg_location
      member :local_input_location
      member :base_location, :default => lambda {Location[Temppath.mkdir]}
      member :interactive_front

      def initialize(*args)
        super(*args)
        @dir = Location[Temppath.mkdir]
        @lock = Mutex.new
        @cv = ConditionVariable.new
      end

      # Fetch source files of the request.
      #
      # @return [void]
      def fetch(&b)
        # size
        fetch_size = files.size + 1
        b.call(1, fetch_size)

        # fetch PPG file
        case self.upload_method
        when "dropbox"
          _ppg = Location[URI.unescape(ppg)]
          self.local_ppg_location = @dir + "ppg" + _ppg.basename
          _ppg.copy(local_ppg_location, keep_mtime: false)
        when "direct"
          self.local_ppg_location = @dir + "ppg" + ppg
          Global.io.push("upload-ppg", ppg)
          @lock.synchronize {@cv.wait(@lock)}
        end
        b.call(2, fetch_size)

        # donwload input files
        self.local_input_location = @dir + "input"
        files.each_with_index do |file, i|
          case self.upload_method
          when "dropbox"
            _file = Location[URI.unescape(file)]
            _file.copy(local_input_location + _file.basename, keep_mtime: false)
          when "direct"
            Global.io.push("upload-file", file)
            @lock.synchronize {@cv.wait(@lock)}
          end
          unless i + 2 > fetch_size
            b.call(i+2, fetch_size)
          end
        end
      end

      def upload_ppg(filename, path)
        Location[path].copy(local_ppg_location, keep_mtime: false)
        @lock.synchronize {@cv.signal}
      end

      def upload_file(filename, path)
        Location[path].copy(local_input_location + filename, keep_mtime: false)
        @lock.synchronize {@cv.signal}
      end

      # Make a zip archive as result of the request.
      #
      # @return [Location::DataLocation]
      #   location of the zip archive
      def make_zip
        zip_location = Location[Temppath.create]
        Util::Zip.compress(base_location, zip_location)
        return zip_location
      end
    end
  end
end
