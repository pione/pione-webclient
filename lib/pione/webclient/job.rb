module Pione
  module Webclient
    class Job
      JOBINFO_FILENAME = "jobinfo.yml"

      attr_accessor :name
      attr_reader :id
      attr_reader :ctime
      attr_reader :mtime
      attr_accessor :status

      def initialize(user, id=nil)
        @user = user
        @name = nil
        @id = nil
        @ctime = nil
        @mtime = nil
        @status = :created

        if id
          @id = id
          read_from_job_info if exist?
        else
          @id = generate_new_id
        end
      end

      def exist?
        jobinfo.exist?
      end

      def delete
        dir.delete
      end

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

      def dir
        @user.dir + @id
      end

      def jobinfo
        dir + "jobinfo.yml"
      end

      def title
        if @name
          "%s(%s)" % [@name, @id]
        else
          @id
        end
      end

      private

      def read_from_job_info
        data = YAML.load(jobinfo.read)
        @name = data[:name]
        @ctime = read_timestamp(data[:ctime])
        @mtime = read_timestamp(data[:mtime])
        @status = data[:status]
      end

      def read_timestamp(timestamp)
        if timestamp
          return Time.iso8601(timestamp)
        end
      end

      def generate_new_id
        Util::UUID.generate
      end
    end
  end
end
