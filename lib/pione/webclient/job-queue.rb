module Pione
  module Webclient
    # `JobQueue` is a queue of process jobs.
    class JobQueue
      attr_reader :fetch_thread
      attr_reader :process_thread
      attr_accessor :message_log_receiver

      def initialize
        @fetch_queue = Queue.new
        @process_queue = SizedQueue.new(Global.job_queue_max)
        @request = Hash.new
        @result = Hash.new
        @message_log_receiver = nil

        # run loops
        run_fetching
        run_processing
      end

      # Add the request into the queue. It constraints max job size, so raise a
      # busy error if the request is not accepted.
      #
      # @param session_id [String]
      #    session ID
      # @param ppg [String]
      #    URL of PPG file
      # @param files [Array<String>]
      #    list of URL of input files
      # @return [void]
      def request(session_id, ppg, files)
        if @fetch_queue.size > Global.job_queue_max
          # server is busy now
          Global.io.push("status", {name: "BUSY"}, to: session_id)
        else
          # cancel if there exists the session's old request already
          cancel(session_id) if @request[session_id]

          # register the request
          _ppg = Location[URI.unescape(ppg)]
          _files = files.map {|file| Location[URI.unescape(file)]}
          req = Request.new(session_id, _ppg, _files)
          @request[session_id] = req
          @fetch_queue.push(req)

          # send an "ACCEPTED" message
          Global.io.push("status", {name: "ACCEPTED"}, to: session_id) if req.active
        end
      end

      # Cancel the request.
      #
      # @param session_id [String]
      #   session ID
      def cancel(session_id)
        if @request[session_id]
          # deactivate the request
          @request[session_id].active = false
          @request.delete(session_id)

          # kill processing PID
          if @processing_request and @processing_pid and @processing_request.session_id == session_id
            Process.kill(:TERM, @processing_pid)
          end

          # push status message
          Global.io.push(:status, {name: "CANCELED"}, :to => session_id)
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
                Global.io.push(:status, {name: "FETCH_ERROR"}, to: req.session_id) if req.active

                # clear the request
                @request.delete(req.session_id)
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
            @request.delete(req.session_id)
          end
        end
      end

      # Fetch source files in the request.
      def fetch(req)
        # push status message
        Global.io.push(:status, {name: "START_FETCHING"}, :to => req.session_id) if req.active

        # fetch source files
        req.fetch do |i, size|
          Global.io.push(:status, {name: "FETCH", number: i, total: size}, :to => req.session_id) if req.active
        end

        # push status message
        Global.io.push(:status, {name: "END_FETCHING"}, :to => req.session_id) if req.active
      end

      # Process the request.
      #
      # @param req [Webclient::Request]
      #   processing request
      # @return [void]
      def process(req)
        @processing_request = req

        # setup message log receiver
        @message_log_receiver.session_id = req.session_id

        # push status message
        Global.io.push(:status, {name: "START_PROCESSING"}, :to => req.session_id) if req.active

        # spawn `pione-client`
        spawner = spawn_pione_client(req)
        @processing_pid = spawner.pid

        # wait to finish processing
        spawner.thread.join if spawner.thread

        # process killed if the request is not active
        return false unless req.active

        # push status message
        Global.io.push(:status, {name: "END_PROCESSING"}, :to => req.session_id)

        return true
      rescue Object => e
        msg = "An error has raised when pione-webclient was processing a job for %s : %s"
        Log::SystemLog.error(msg % [req.session_id, e.message])
        Global.io.push(:status, {name: "ERROR"}, :to => req.session_id)
      ensure
        @message_log_receiver.session_id = nil
        @processing_request = nil
        @processing_pid = nil
      end

      # Spawn `pione-client` for the request.
      #
      # @return [Command::Spawner]
      #   spawned process
      def spawn_pione_client(req)
        # bundle exec pione-client
        spawner = Command::Spawner.new("pione-client")

        # options
        if req.local_input_location.exist?
          spawner.option("--input", req.local_input_location.address)
        end
        spawner.option("--output", req.base_location.address)
        spawner.option("--parent-front", Global.front.uri)
        # if Global.presence_notification_addresses
        #   Global.presence_notification_addresses.each do |address|
        #     spawner.option("--presence-notification-address", address.to_s)
        #   end
        # end
        spawner.option("--stand-alone") if Global.stand_alone

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
        Global.io.push(:status, {name: "COMPLETED"}, :to => req.session_id)
      end
    end

    # `Request` is a class that represents processing requests.
    class Request < StructX
      member :session_id
      member :ppg
      member :files
      member :active, :default => true
      member :local_ppg_location
      member :local_input_location
      member :base_location, :default => lambda {Location[Temppath.mkdir]}

      # Fetch source files of the request.
      #
      # @return [void]
      def fetch(&b)
        dir = Location[Temppath.mkdir]

        # size
        fetch_size = files.size + 1
        b.call(0, fetch_size)

        # fetch PPG file
        self.local_ppg_location = dir + "ppg" + ppg.basename
        ppg.copy(local_ppg_location, keep_mtime: false)
        b.call(1, fetch_size)

        # donwload input files
        self.local_input_location = dir + "input"
        files.each_with_index do |file, i|
          file.copy(local_input_location + file.basename, keep_mtime: false)
          b.call(i+1, fetch_size)
        end
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
