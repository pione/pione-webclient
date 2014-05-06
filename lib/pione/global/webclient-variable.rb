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

    define_internal_item(:interactive_operation_manager) do |item|
      item.desc = "Interactive operation manager for webclient."
    end

    define_external_item(:stand_alone) do |item|
      item.desc = "Spawn pione-client with stand alone mode"
      item.init = false
    end

    define_internal_item(:dropins_app_key) do |item|
      item.desc = "Drop-ins app key"
    end

    define_internal_item(:resource) do |item|
      item.desc = "Resource table"
    end

    define_internal_item(:bootstrap_version) do |item|
      item.desc = "Version of Bootstrap"
      item.init = "3.1.1"
    end

    define_internal_item(:jquery_version) do |item|
      item.desc = "Version of jQuery"
      item.init = "1.10.2"
    end
  end
end
