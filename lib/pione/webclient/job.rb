module Pione
  module Webclient
    # Job is a model for job in Pione webclient.
    class Job
      # job information filename
      JOBINFO_FILENAME = "job-info.yml"

      attr_accessor :name
      attr_reader :id
      attr_reader :ctime
      attr_reader :mtime
      attr_accessor :status

      # @param [User] user
      #   user object
      # @param [String] id
      #   job ID
      def initialize(user, id=nil)
        @user = user
        @name = nil
        @id = nil
        @ctime = nil
        @mtime = nil
        @status = :created

        if id
          @id = id
          read_from_jobinfo if exist?
        else
          @id = generate_new_id
        end
      end

      # Return true if the job exists in workspace.
      def exist?
        jobinfo.exist?
      end

      # Delete the job directory.
      # @return [void]
      def delete
        dir.delete
      end

      # Save the job information.
      # @return [void]
      def save
        now = Time.now

        data = {
          :id     => @id,
          :name   => @name,
          :ctime  => (@ctime || now).iso8601,
          :mtime  => now.iso8601,
          :status => @status,
        }
        jobinfo.write(YAML.dump(data))
      end

      # Return the location of job directory.
      # @return [Location]
      #   the location of job directory
      def dir
        @user.dir + @id
      end

      # Return the location of job information file.
      # @return [Location]
      #   the location of job information file
      def jobinfo
        dir + JOBINFO_FILENAME
      end

      def results_dir(filename)
        dir + "results"
      end

      private

      # Read job informations from job information file.
      # @return [void]
      def read_from_jobinfo
        data = YAML.load(jobinfo.read)
        @name = data[:name]
        @ctime = parse_timestamp(data[:ctime])
        @mtime = parse_timestamp(data[:mtime])
        @status = data[:status]
      end

      # Parse the timestamp string as a date object. This assumes the timestamp
      # is ISO8601 format.
      #
      # @return [void]
      def parse_timestamp(timestamp)
        if timestamp
          return Time.iso8601(timestamp)
        end
      end

      # Generate a new job ID.
      def generate_new_id
        Util::UUID.generate
      end
    end
  end
end
