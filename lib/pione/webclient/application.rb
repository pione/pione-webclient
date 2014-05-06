module Pione
  module Webclient
    # `WebClient::Application` is a sinatra application.
    class Application < Sinatra::Base
      set :server, 'thin'
      set :port, Global.webclient_port
      set :public_folder, Global.webclient_root + 'public'
      use Rack::CommonLogger

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
      # event handlers
      #

      # Request a job.
      Global.io.on("request") do |data, client|
        Global.job_queue.request(client.session, data["uploadMethod"], data["ppg"], data["files"])
      end

      # Cancel the job.
      Global.io.on("cancel") do |_, client|
        Global.job_queue.cancel(client.session)
      end

      # finish interactive operation
      Global.io.on("finish-interactive-operation") do |data, client|
        Global.interactive_operation_manager.finish(client.session, data)
      end

      #
      # upload
      #
      post '/upload/ppg/:session_id' do
        if (req = Global.job_queue.find_request(params[:session_id]))
          req.upload_ppg(params[:file][:filename], params[:file][:tempfile].path)
        end
      end

      post '/upload/file/:session_id' do
        if (req = Global.job_queue.find_request(params[:session_id]))
          req.upload_file(params[:file][:filename], params[:file][:tempfile].path)
        end
      end

      #
      # target files
      #

      # Send the processing result zip file of the session.
      get '/result/:uuid/*.zip' do
        if zip_location = Global.job_queue.result(params[:uuid])
          content_type "application/zip"
          last_modified zip_location.mtime

          send_file(zip_location.path.to_s)
        else
          return 404, "no results"
        end
      end

      #
      # Admin
      #

      get '/shutdown' do
        Global.io.push(:status, "SHUTDOWN")
        sleep 5
        puts "!!! PIONE Webclient shutdowned !!!"
        exit!
      end
    end
  end
end
