module Pione
  module Webclient
    class DownloadQueue
      def initialize(workspace, websocket_manager)
        @queue = Queue.new
        @workspace = workspace
        @websocket_manager = websocket_manager
        start
      end

      def add(job_id, filename, url, dest)
        @queue.push(job_id: job_id, filename: filename, url: url, dest: dest)
      end

      private

      def start
        Thread.new do
          while recored = @queue.pop do
            job_id = record[:job_id]

            if @workspace.find_job(job_id)
              remote = Location[URI.unescape(recored[:url])]
              remote.copy(record[:dest])

              # notify the status
              Global.io.push("fetch", {filename: record[filename]}, to: @websocket_manager.find(job_id))
            end
          end
        end
      end
    end
  end
end
