module Pione
  module Global
    define_internal_item(:webclient_root) do |item|
      item.desc = "Root path of PIONE webclient."
      item.init = Pathname.new(File.dirname(__FILE__)) + ".." + ".." + ".."
    end

    define_external_item(:webclient_port) do |item|
      item.desc = "port number of pione-webclient."
      item.init = 56001
    end

    define_external_item(:webclient_front_port_range) do |item|
      item.desc = "port number range of pione-webclient front."
      item.init = 56500..56999
    end

    define_internal_item(:io) do |item|
      item.desc = "SocketIO interface."
      item.init = Sinatra::RocketIO
    end

    define_internal_item(:job_queue) do |item|
      item.desc = "Job manager for webclient."
    end

    define_external_item(:job_queue_max) do |item|
      item.desc = "Max size of job queue."
      item.init = 5
    end

    define_external_item(:stand_alone) do |item|
      item.desc = "Spawn pione-client with stand alone mode"
      item.init = false
    end

    define_internal_item(:dropins_app_key) do |item|
      item.desc = "Drop-ins app key"
    end
  end
end
