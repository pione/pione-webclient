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
        if processable? or unset?
          dir.delete
        else
          raise JobError.cannot_delete(@id, state)
        end
      end

      # Save the job information.
      # @return [void]
      def save
        now = Time.now

        data = {
          :id           => @id,
          :desc         => @desc,
          :ctime        => Timestamp.dump(@ctime) || Timestamp.dump(now),
          :mtime        => Timestamp.dump(now),
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
        filename = basename(filename)
        @ppg_filename = filename
        ppg = ppg_location + filename
        Location[filepath].copy(ppg)
        ppg.mtime = Time.now
        save
      end

      def upload_input_by_file(filename, filepath)
        filename = basename(filename)
        location = input_location + filename
        Location[filepath].copy(location)
        location.mtime = Time.now
      end

      def upload_ppg_by_url(filename, url)
        filename = basename(filename)
        @ppg_filename = filename
        Global.download_queue.add(@id, url, ppg_location + filename)
        save
      end

      def upload_input_by_url(filename, url)
        filename = basename(filename)
        Global.download_queue.add(@id, url, input_location + filename)
      end

      def delete_ppg(filename)
        filename = basename(filename)
        ppg = ppg_location + filename
        return ppg.exist? ? ppg.delete : false
      end

      def delete_input(filename)
        filename = basename(filename)
        input = input_location + filename
        return input.exist? ? input.delete : false
      end

      def delete_result(filename)
        result = result_file(filename)
        return result ? result.delete : false
      end

      def ppg_file(filename)
        filename = basename(filename)
        ppg = ppg_location + filename
        return ppg.exist? ? ppg : nil
      end

      def input_file(filename)
        filename = basename(filename)
        input = input_location + filename
        return input.exist? ? input : nil
      end

      def result_file(filename)
        result = result_location + filename
        return result.exist? ? result : nil
      end

      def find_inputs
        if input_location.exist?
          return input_location.entries.each_with_object([]) do |entry, sources|
            if entry.file?
              sources << entry
            end
          end
        else
          return []
        end
      end

      # Find all result
      def find_results
        if result_location.exist?
          return result_location.entries.each_with_object([]) do |entry, sources|
            if entry.file?
              sources << entry
            end
          end
        else
          return []
        end
      end

      # Clear current base directory.
      def clear_base_location
        tmpdir = dir + "base_removed"
        base_location.move(tmpdir)
        base_location.mkdir
        tmpdir.delete
      end

      # Return the job status. The status is one of the followings:
      # - init
      # - unset
      # - procceable
      # - processing
      # - deleted
      def status
        if not(exist?)
          return :init
        end

        if @ppg_filename.nil?
          return :unset
        end

        if Global.job_queue.active?(@id)
          return :processing
        end

        return :processable
      end

      # Return ture if the job is state "init".
      def init?
        status == :init
      end

      # Return true if the job is state "unset".
      def unset?
        status == :unset
      end

      # Return true if the job is state "processable".
      def processable?
        status == :processable
      end

      # Return true if the job is state "processing".
      def processing?
        status == :processing
      end

      # Return true if the job is state "deleted".
      def deleted?
        status == :deleted
      end

      # Make a zip archive as result of the request.
      #
      # @return [Location::DataLocation]
      #   location of the zip archive
      def make_zip(filename)
        filename = basename(filename)
        zip = result_location + filename
        Util::Zip.compress(base_location, zip)
        return zip
      end

      private

      def basename(filename)
        Pathname.new(filename).basename
      end

      # Read job informations from job information file.
      # @return [void]
      def read_from_jobinfo
        data = YAML.load(jobinfo.read)
        @desc = data[:desc]
        @ctime = Timestamp.parse(data[:ctime])
        @mtime = Timestamp.parse(data[:mtime])
        @ppg_filename = data[:ppg_filename]
      end

      # Generate a new job ID.
      def generate_new_id
        Util::UUID.generate
      end
    end

    class JobError < StandardError
      def self.cannot_delete(id, state)
        'Cannot delete the job because of the state "%s". (ID: "%s")' % [state, id]
      end
    end
  end
end
