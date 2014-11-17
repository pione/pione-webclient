module Pione
  module Webclient
    class User
      USERINFO_FILENAME = "user-info.yml"

      attr_reader :name
      attr_reader :ctime
      attr_reader :mtime

      # @param [String] name
      #   user name
      # @param [Workspace] workspace
      #   workspace object
      def initialize(name, workspace)
        @name = name
        @workspace = workspace
        @password = nil
        @ctime = nil
        @mtime = nil

        load_from_userinfo if exist?
      end

      # Return true if the user exists.
      # @return [Boolean]
      #   true if the user exists
      def exist?
        userinfo.exist?
      end

      def admin?
        @workspace.admin?(@name)
      end

      # Return true if the password is valid.
      # @param [String] password
      #   password
      # @return [Boolean]
      #   true if the password is valid
      def auth(password)
        password = password.downcase
        exist? and validate_password_format(password) and @password == password
      end

      # Delete the user. This deletes all of files in user directory.
      # @return [void]
      def delete
        dir.delete
      end

      # Set the password. Return true if the password's format is valid.
      def set_password(password)
        password = password.downcase
        if validate_password_format(password)
          @password = password
          return true
        else
          return false
        end
      end

      # Save the user's information.
      # @return [void]
      def save
        now = Time.now

        data = {
          :name => @name,
          :password => @password,
          :ctime => Timestamp.dump(@ctime) || Timestamp.dump(now),
          :mtime => Timestamp.dump(now),
        }
        userinfo.write(YAML.dump(data))
      end

      # Return the location of user directory.
      # @return [Location]
      #   the location of user directory
      def dir
        # TODO: escape user name
        @workspace.dir + @name
      end

      # Return the location of user information file.
      # @return [Location]
      #   the location of user information file
      def userinfo
        dir + USERINFO_FILENAME
      end

      # Find jobs from the user directory.
      # @return [Array<String>]
      #   list of job ID
      def find_jobs
        dir.entries.each_with_object([]) do |entry, jobs|
          if (entry + Job::JOBINFO_FILENAME).exist?
            jobs << Job.new(self, entry.basename)
          end
        end
      end

      private

      # Load user informations from user information file.
      # @return [void]
      def load_from_userinfo
        data = YAML.load(userinfo.read)
        @password = data[:password]
        @ctime = Timestamp.parse(data[:ctime])
        @mtime = Timestamp.parse(data[:mtime])
      end

      # Check the password is valid or invalid. The password should be a SHA512
      # HEX digest of string that is sequence of user name, ':', real password.
      def validate_password_format(password)
        /^[0-9a-f]{128}$/ === password
      end
    end

    class UserError < StandardError
      def self.invalid_password_format
        UserError.new("The password is invalid.")
      end
    end
  end
end
