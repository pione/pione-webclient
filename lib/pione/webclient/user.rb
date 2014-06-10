module Pione
  module Webclient
    class User
      USERINFO_FILENAME = "userinfo.yml"

      # @param [String] name
      #   user name
      # @param [Location] workspace_root
      #   workspace root directory
      def initialize(name, workspace_root)
        @name = name
        @workspace_root = workspace_root
        @password = nil

        load_from_userinfo if exist?
      end

      # Return true if the user exists.
      # @return [Boolean]
      #   true if the user exists
      def exist?
        userinfo.exist?
      end

      # Return true if the password is valid.
      # @param [String] password
      #   password
      # @return [Boolean]
      #   true if the password is valid
      def auth(password)
        return false unless exist?

        @password == password_digest(password)
      end

      # Delete the user. This deletes all of files in user directory.
      # @return [void]
      def delete
        userdir.delete
      end

      def set_password(password)
        @password = password_digest(password)
      end

      # Save the user's information.
      # @return [void]
      def save
        data = Hash.new
        data[:name] = @name
        data[:password] = @password
        userinfo.write(YAML.dump(data))
      end

      # Return the location of user directory.
      # @return [Location]
      #   the location of user directory
      def dir
        # TODO: escape user name
        @workspace_root + @name
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
      end

      def password_digest(password)
        Digest::SHA512.hexdigest(@name + password).to_s
      end
    end
  end
end
