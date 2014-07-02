module Pione
  module Webclient
    # Job is a model for job in Pione webclient.
    class Job
      # job information filename
      JOBINFO_FILENAME = "job-info.yml"

      attr_reader :id
      attr_accessor :desc
      attr_reader :ctime
      attr_reader :mtime
      attr_accessor :status
      attr_reader :ppg_filename

      # @param [User] user
      #   user object
      # @param [String] id
      #   job ID
      def initialize(user, id=nil)
        @user = user
        @desc = nil
        @id = nil
        @ctime = nil
        @mtime = nil
        @status = :created
        @ppg_filename = nil

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
          :desc   => @desc,
          :ctime  => Timestamp.dump(@ctime) || Timestamp.dump(now),
          :mtime  => Timestamp.dump(now),
          :status => @status,
          :ppg_filename => @ppg_filename,
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

      def base_location
        dir + "base"
      end

      def result_location
        dir + "results"
      end

      def input_location
        dir + "input"
      end

      def ppg_location
        dir + "ppg"
      end

      def upload_ppg_by_file(filename, filepath)
        @ppg_filename = filename
        ppg = ppg_location + filename
        Location[filepath].copy(ppg)
        ppg.mtime = Time.now
        save
      end

      def upload_source_by_file(filename, filepath)
        location = input_location + filename
        Location[filepath].copy(location)
        location.mtime = Time.now
      end

      def upload_ppg_by_url(filename, url)
        @ppg_filename = filename
        Global.download_queue.add(@id, url, ppg_location + filename)
        save
      end

      def upload_source_by_url(filename, url)
        Global.download_queue.add(@id, url, input_location + filename)
      end

      def find_sources
        if input_location.exist?
          return input_location.entries.each_with_object([]) do |entry, sources|
            if entry.file?
              sources << entry.basename
            end
          end
        else
          return []
        end
      end

      # Clear current base directory.
      def clear_base_location
        tmpdir = @dir + "base_removed"
        base_location.move(tmpdir)
        base_location.mkdir
        tmpdir.delete
      end

      def requestable?
        exist? and not(@ppg_filename.nil?) and not(Global.job_queue.active?(@id))
        # TODO: we should consider download queue
      end

      # Make a zip archive as result of the request.
      #
      # @return [Location::DataLocation]
      #   location of the zip archive
      def make_zip(filename)
        zip = zip_location + filename
        Util::Zip.compress(base_location, zip)
        return zip
      end

      private

      # Read job informations from job information file.
      # @return [void]
      def read_from_jobinfo
        data = YAML.load(jobinfo.read)
        @desc = data[:desc]
        @ctime = Timestamp.parse(data[:ctime])
        @mtime = Timestamp.parse(data[:mtime])
        @status = data[:status]
        @ppg_filename = data[:ppg_filename]
      end

      # Generate a new job ID.
      def generate_new_id
        Util::UUID.generate
      end
    end
  end
end
