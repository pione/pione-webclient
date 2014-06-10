module Pione
  module Webclient
    class Workspace
      def initialize(dir)
        @dir
      end

      def find_user_names
        @dir.entries.each_with_object([]) do |entry, users|
          if (entry + User::USERINFO_FILENAME).exist?
            users << entry.basename
          end
        end
      end
    end
  end
end
