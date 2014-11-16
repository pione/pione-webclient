module Pione
  module Webclient
    # Resource is a table of strings that consists name and its value. This is
    # used as an abstraction of library paths and etc. Resource data exist in
    # resource file, for example "resource.production.yml" or
    # "resource.development.yml".
    class Resource
      # Return the default path of the environment's resource file.
      #
      # @param [Symbol] environment
      #   environment name
      # @return [Pathname]
      #   resource file path of the environment
      def self.default_resource_file(environment)
        Pathname.new(File.join(File.dirname(__FILE__), "resource.%s.yml" % environment))
      end

      def initialize
        @table = Hash.new
      end

      # Load the environment's resource data.
      #
      # @param [Symbol] environment
      #   environment name
      # @return [void]
      def load(path)
        @table.merge!(YAML.load(path.read))
      end

      # Get the value of the resource name.
      #
      # @param [symbol] name
      #   a resource name
      # @return [String]
      #   the value
      def [](name)
        msg = @table[name.to_s]
        data = Hash.new
        msg.scan(/%{([a-zA-Z0-9_]+?)}/) do |keys|
          keys.each do |key|
            data[key.to_sym] = Global.get(key.to_sym)
          end
        end
        msg % data
      end
    end
  end
end
