module Pione
  module WebClient
    class ProcessingType < StructX
      class << self
        def read
          location = Global.webclient_root + "config" + "processing-type.yml"
          YAML.load(location.read).map {|name, location| new(name, location)}
        end
      end

      member :name
      member :location
    end
  end
end
