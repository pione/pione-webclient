module Pione
  module Webclient
    # `WebClient::Application` is a sinatra application.
    class Application < Sinatra::Base
      enable :sessions

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

      before do
        unless request.path_info == "/login"
          unless session[:email]
            session[:referer] = request.fullpath;
            redirect '/login'
          end
        end
      end

      #
      # login
      #

      get '/login' do
        unless session[:email]
          template = Location[settings.views] + "login.erb"
          last_modified template.mtime
          erb :login
        else
          redirect '/'
        end
      end

      post '/login' do
        user = User.new(params[:email], Global.workspace_root)

        case params[:submit_type]
        when "login"
          if user.auth(params[:password])
            session[:email] = params[:email]

            if referer = session[:referer]
              session[:referer] = nil
              redirect session[:referer]
            else
              redirect '/'
            end
          else
            session[:message] = "Login failed because of no such user or bad password."
          end
        when "signup"
          unless user.exist?
            # save user informations
            user.set_password(params[:password])
            user.save

            # store the user informations to session
            session[:email] = params[:email]
            session[:referer] = nil

            # go to previous page
            if referer = session[:referer]
              session[:referer] = nil
              redirect session[:referer]
            else
              redirect '/'
            end
          else
            session[:message] = "The account exists already."
          end
        end

        redirect '/login'
      end

      get '/logout' do
        session[:email] = nil
        redirect '/login'
      end

      #
      # main page
      #

      # Show workspace page.
      get '/' do
        user = User.new(session[:email], Global.workspace_root)
        jobs = user.find_jobs

        erb :workspace, :locals => {:jobs => jobs}
      end

      # Create a new job.
      post '/job/create' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, nil)
        job.name = params[:job_name]

        if job.exist?
          redirect '/job/create'
        else
          job.save
          redirect '/job/' + job.id
        end
      end

      # Show job control page.
      get '/job/:job_id' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])

        template = Location[settings.views] + "job.erb"
        last_modified template.mtime
        erb :job, :locals => {:job => job}
      end

      # Delete the job and go home.
      get '/job/delete/:job_id' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])

        if job.exist?
          job.delete
        end

        redirect '/'
      end

      #
      # event handlers
      #

      # Request a job.
      Global.io.on("request") do |data, client|
        Global.job_queue.request(data["job_id"], data["uploadMethod"], data["ppg"], data["files"])
      end

      # Cancel the job.
      Global.io.on("cancel") do |data, client|
        Global.job_queue.cancel(data["job_id"])
      end

      # finish interactive operation
      Global.io.on("finish-interactive-operation") do |data, client|
        Global.interactive_operation_manager.finish(data["job_id"], data)
      end

      #
      # upload
      #
      post '/upload/ppg/:job_id' do
        if (req = Global.job_queue.find_request(params[:job_id]))
          req.upload_ppg(params[:file][:filename], params[:file][:tempfile].path)
        end
      end

      post '/upload/file/:job_id' do
        if (req = Global.job_queue.find_request(params[:job_id]))
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
      # Interactive Operation
      #

      get %r{/interactive/(\w+)/(.+)} do |session_id, path|
        if (req = Global.job_queue.find_request(session_id))
          file = Location[Temppath.mkdir] + path
          pione_interactive = DRb::DRbObject.new_with_uri(req.interactive_front)
          if data = pione_interactive.file(path)
            file.write(data)
            send_file(file.path.to_s)
          else
            return 404, "file not found"
          end
        end
      end

      post '/interactive/:job_id/' do
        send_file(req.working_directory + "index.html")
      end

      post '/interactive/:job_id/finish' do
        # finish interactive operation
        Global.interactive_operation_manager.finish(params[:job_id], params[:result])

        "Interactive operation has finished."
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
