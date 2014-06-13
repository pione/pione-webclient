module Pione
  module Webclient
    class Workspace
      WORKSPACE_INFO_FILENAME = "workspace-info.yml"

      # @param [Location] dir
      #   the location of workspace directory.
      def initialize(dir)
        @dir = dir
        @title = nil

        if exist?
          load
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

      # Find users in this workspace.
      def find_users
        @dir.entries.each_with_object([]) do |entry, users|
          user_name = entry.basename
          user = User.new(user_name, @dir)
          if user.exist?
            users << user
          end
        end
      end

      # Save workspace informations.
      def save
        data = {
          :title => @title,
        }
        workspace_info.write(YAML.dump(data))
      end

      # Load workspace informations.
      def load
        data = YAML.load(workspace_info.read)
        @title = data[:title]
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
