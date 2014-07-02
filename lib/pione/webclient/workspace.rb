module Pione
  module Webclient
    class Workspace
      WORKSPACE_INFO_FILENAME = "workspace-info.yml"

      attr_accessor :title

      # @param [Location] dir
      #   the location of workspace directory.
      def initialize(dir)
        @dir = dir
        @title = nil
        @ctime = nil
        @mtime = nil

        if exist?
          load
        end
      end

      def title
        @title || "PIONE Webclient"
      end

      def title=(name)
        if name and name.size > 0
          @title = name
        else
          @title = nil
        end
      end

      # Return true if the workspace exists.
      def exist?
        workspace_info.exist?
      end

      # Return true if no users exist.
      def empty?
        find_users.empty?
      end

      # Find a job by id.
      def find_job(job_id)
        find_users.each do |user|
          user.find_jobs.each do |job|
            return job if job.id == job_id
          end
        end

        return nil
      end

      # Find users in this workspace.
      def find_users
        if @dir.exist?
          return @dir.entries.each_with_object([]) do |entry, users|
            user_name = entry.basename
            user = User.new(user_name, @dir)
            if user.exist?
              users << user
            end
          end
        else
          return []
        end
      end

      # Save workspace informations.
      def save
        now = Time.now
        data = {
          :title => @title,
          :ctime => Timestamp.dump(@ctime) || Timestamp.dump(now),
          :mtime => Timestamp.dump(now),
        }
        workspace_info.write(YAML.dump(data))
      end

      # Load workspace informations.
      def load
        data = YAML.load(workspace_info.read)
        @title = data[:title]
        @ctime = Timestamp.parse(data[:ctime])
        @mtime = Timestamp.parse(data[:mtime])
      end

      # Return the location of workspace information file.
      # @return [Location]
      #   the location of workspace information file
      def workspace_info
        @dir + WORKSPACE_INFO_FILENAME
      end
    end
  end
end
