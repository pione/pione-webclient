module Pione
  module Webclient
    # `WebClient::Application` is a sinatra application.
    class Application < Sinatra::Base
      set :server, 'thin'
      set :port, Global.webclient_port
      set :public_folder, Global.webclient_root + 'public'

      #
      # common
      #

      enable :sessions
      register Sinatra::RocketIO

      configure :development do
        register Sinatra::Reloader
      end

      #
      # main page
      #

      get '/' do
        template = Location[settings.views] + "index.erb"
        last_modified template.mtime
        erb :index
      end

      #
      # job
      #

      # Request a job.
      Global.io.on("request") do |data, client|
        Global.job_manager.request(client.session, data["ppg"], data["files"])
      end

      # Cancel the job.
      Global.io.on("cancel") do |_, client|
        Global.job_manager.cancel(client.session)
      end

      # Send the processing result zip file of the session.
      get '/result/:uuid/*.zip' do
        if zip_location = Global.job_manager.zip(params[:uuid])
          content_type "application/zip"
          last_modified zip_location.mtime

          send_file(zip_location.path.to_s)
        else
          return 404, "no results"
        end
      end
    end
  end
end
