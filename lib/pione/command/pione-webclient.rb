module Pione
  module Command
    # This is a body for +pione-webclient+ command.
    class PioneWebclient < BasicCommand
      #
      # basic informations
      #

      define(:toplevel, true)
      define(:name, "pione-webclient")
      define(:desc, "`pione-webclient` is a PIONE client provides web interface.")
      define(:front, Pione::Front::WebclientFront)

      #
      # options
      #

      option :color
      option :debug
      option :communication_address

      option(:environment) do |item|
        item.type  = :string
        item.short = '-e'
        item.long  = '--environment'
        item.arg   = 'MODE'
        item.desc  = 'set a environment name'
        item.assign {|name| name.to_sym}
      end

      option(:stand_alone) do |item|
        item.long = '--stand-alone'
        item.desc = 'turn on stand alone mode'
        item.process {Global.stand_alone = true}
      end

      #
      # command lifecycle: setup phase
      #

      phase(:setup) do |seq|
        seq << :environment
        seq << :resource
        seq << :websocket_manager
        seq << :job_queue
        seq << :download_queue
        seq << :interactive_operation_manager
        seq << :dropins_app_key
        seq << :message_log_receiver
        seq << :running_environment
      end

      setup(:environment) do |item|
        item.desc = "Setup the webclient's environment"
        item.process {model[:environment] ||= :development}
      end

      setup(:resource) do |item|
        item.desc = "Load application resource"
        item.process do
          Global.resource = Webclient::Resource.new
          if model[:resource_file]
            path = model[:resource_file]
          else
            path = Webclient::Resource.default_resource_file(model[:environment])
          end
          begin
            Global.resource.load(path)
          rescue Errno::ENOENT
            abort("Resource file not found: %s" % path)
          end
        end
      end

      setup(:websocket_manager) do |item|
        item.desc = "Setup Websocket manageer."
        item.process do
          Global.websocket_manager = Webclient::WebsocketManager.new
        end
      end

      setup(:job_queue) do |item|
        item.desc = "Start a job queue"
        item.process do
          Global.job_queue = Webclient::JobQueue.new(model, Global.websocket_manager)
        end
      end

      setup(:download_queue) do |item|
        item.desc = "Start a download queue"
        item.process do
          workspace = Webclient::Workspace.new(Global.workspace_root)
          Global.download_queue = Webclient::DownloadQueue.new(workspace, Global.websocket_manager)
        end
      end

      setup(:interactive_operation_manager) do |item|
        item.desc = "Start an interactive operation manager"
        item.process do
          Global.interactive_operation_manager = Pione::Webclient::InteractiveOperationManager.new
        end
      end

      setup(:dropins_app_key) do |item|
        item.desc = "Setup Drop-ins Appkey"
        item.process do
          dropins_app_key_path = Global.webclient_root + "dropins-app-key.txt"
          if dropins_app_key_path.exist?
            Global.dropins_app_key = dropins_app_key_path.read.chomp
          else
            if model[:environment] == :production
              abort("You should create Drop-ins app key file at %s" % dropins_app_key_path)
            else
              Global.dropins_app_key = ""
            end
          end
        end
      end

      # Setup a message log receiver. This receiver sends message logs to
      # client's browser.
      setup(:message_log_receiver) do |item|
        item.desc = "Setup a message log receiver"
        item.process do
          receiver = Log::WebclientMessageLogReceiver.new(Global.websocket_manager)
          model[:front][:message_log_receiver] = receiver
          Global.job_queue.message_log_receiver = receiver
        end
      end

      # Setup webclient's running environment.
      setup(:running_environment) do |item|
        item.desc = "Setup the environment"
        item.process do
          Webclient::Application.set(:environment, model[:environment] || :development)
        end
      end

      #
      # command lifecycle: execution phase
      #

      phase(:execution) do |seq|
        seq << :sinatra_application
      end

      execution(:sinatra_application) do |item|
        item.desc = "Execute webclient as a sinatra application"
        item.process do
          Webclient::Application.run!
        end
      end
    end
  end
end
