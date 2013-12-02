module Pione
  module Command
    # This is a body for +pione-webclient+ command.
    class PioneWebclient < BasicCommand
      #
      # basic informations
      #

      command_name("pione-webclient") {"front: %s" % [Global.front.uri]}
      command_banner("`pione-webclient` is a PIONE client provides web interface.")
      command_front Pione::Front::WebclientFront

      #
      # options
      #

      use_option :color
      use_option :debug
      use_option :communication_address

      define_option(:environment) do |item|
        item.short = '-e'
        item.long = '--environment=MODE'
        item.desc = 'set a environment name'
        item.value = lambda {|name| name.to_sym}
      end

      define_option(:stand_alone) do |item|
        item.long = '--stand-alone'
        item.desc = 'turn on stand alone mode'
        item.action = lambda {|_, _, _| Global.stand_alone = true}
      end

      #
      # command lifecycle: setup phase
      #

      setup :dropins_app_key
      setup :message_log_receiver
      setup :running_environment

      def setup_dropins_app_key
        dropins_app_key_path = Global.webclient_root + "dropins-app-key.txt"
        if dropins_app_key_path.exist?
          Global.dropins_app_key = dropins_app_key_path.read.chomp
        else
          abort("You should create Drop-ins app key file at %s" % dropins_app_key_path)
        end
      end

      # Setup a message log receiver. This receiver sends message logs to
      # client's browser.
      def setup_message_log_receiver
        receiver = Log::WebclientMessageLogReceiver.new
        Global.front[:message_log_receiver] = receiver
        Global.job_manager.message_log_receiver = receiver
      end

      # Setup webclient's running environment.
      def setup_running_environment
        Webclient::Application.set(:environment, option[:environment] || :development)
      end

      #
      # command lifecycle: execution phase
      #

      execute :sinatra_application

      def execute_sinatra_application
        Webclient::Application.run!
      end
    end
  end
end
