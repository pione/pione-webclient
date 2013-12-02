module Pione
  module Webclient
    # `JobManager` is a manager of process jobs.
    class JobManager
      attr_reader :fetching_loop_thread
      attr_reader :processing_loop_thread
      attr_accessor :message_log_receiver

      def initialize
        @job_queue = Queue.new
        @processable_queue = Queue.new
        @table = Hash.new
        @result = Hash.new
        @message_log_receiver = nil

        # run loops
        run_fetching_loop
        run_processing_loop
      end

      # Run a loop for fetching source files.
      #
      # @return [void]
      def run_fetching_loop
        @fetching_loop_thread = Thread.new do
          loop do
            # pop a request
            req = @job_queue.pop

            if req.active
              begin
                fetch(req)
                @processable_queue.push(req)
              rescue Object => e
                # send status
                Global.io.push(:status, "FETCH_ERROR", to: req.session_id)

                # clear the request from request table
                @table[req.session_id] = nil
              end
            end
          end
        end
      end

      # Run a loop for processing jobs.
      #
      # @return [void]
      def run_processing_loop
        @processing_thread = Thread.new do
          loop do
            # pop a request
            req = @processable_queue.pop

            # process the request
            if req.active
              process(req)
            end

            # remove the request from request table
            @table[req.session_id] = nil
          end
        end
      end

      # Add the request. It goes into job queue.
      #
      # @param session_id [String]
      #    session ID
      # @param ppg [String]
      #    URL of PPG file
      # @param files [Array<String>]
      #    list of URL of input files
      # @return [void]
      def request(session_id, ppg, files)
        if @job_queue.size > Global.job_queue_max
          # server is busy now
          Global.io.push("status", "BUSY", to: session_id)
        else
          # cancel if there exists the session's old request already
          cancel(session_id) if @table[session_id]

          # register the request
          _ppg = Location[URI.unescape(ppg)]
          _files = files.map{|file| Location[URI.unescape(file)]}
          req = Request.new(session_id, _ppg, _files)
          @job_queue.push(req)
          @table[session_id] = req

          # send an "ACCEPTED" message
          Global.io.push("status", "ACCEPTED", to: session_id)
        end
      end

      # Cancel the request.
      #
      # @param session_id [String]
      #   session ID
      def cancel(session_id)
        if @current_job.session_id == session_id
          @current_job.terminate
        else
          # deactivate the request
          @table[session_id].active = false
          @table[session_id] = nil
        end

        # push status message
        Global.io.push(:status, "CANCELED", :to => session_id)
      end

      # Fetch source files in the request.
      def fetch(req)
        # push status message
        Global.io.push(:status, "START_FETCHING", :to => req.session_id)

        # fetch source files
        req.fetch
      end

      # Process the request.
      #
      # @param req [Webclient::Request]
      #   processing request
      # @return [void]
      def process(req)
        @current_job = req

        # setup message log receiver
        @message_log_receiver.session_id = req.session_id

        # bundle exec pione-client
        spawner = Command::Spawner.new("bundle")
        spawner.option("exec")
        spawner.option("pione-client")

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
        if Global.stand_alone
          spawner.option("--stand-alone")
        end

        # arguements
        spawner.option(req.local_ppg_location.address)

        spawner.spawn

        # push status message
        Global.io.push(:status, "PROCESSING", :to => req.session_id)

        # wait to finish processing
        spawner.thread.join if spawner.thread

        # push status message
        Global.io.push(:status, "FINISHING", :to => req.session_id)

        # make the result zip file
        uuid = Util::UUID.generate
        zip_location = req.make_zip
        filename = "pione-" + zip_location.mtime.strftime("%Y%m%d%H%M%S") + ".zip"
        @result[uuid] = req.make_zip
        Global.io.push(:result, {uuid: uuid, filename: filename}, :to => req.session_id)

        # push status message
        Global.io.push(:status, "COMPLETED", :to => req.session_id)
      ensure
        @message_log_receiver.session_id = nil
      end

      # Return zip file location of the session ID.
      #
      # @param uuid [String]
      #   UUID
      # @return [Location::DataLocation]
      #   zip location
      def zip(uuid)
        @result[uuid]
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

      def fetch
        dir = Location[Temppath.mkdir]

        # fetch ppg file
        self.local_ppg_location = dir + "ppg" + ppg.basename
        ppg.copy(local_ppg_location, keep_mtime: false)

        # donwload input files
        self.local_input_location = dir + "input"
        files.each {|file| file.copy(local_input_location + file.basename, keep_mtime: false)}
      end

      def make_zip
        zip_location = Location[Temppath.create]
        Util::Zip.compress(base_location, zip_location)
        return zip_location
      end
    end
  end
end
