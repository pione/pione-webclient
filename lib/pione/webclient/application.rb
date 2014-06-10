module Pione
  module Webclient
    class ApplicationUtil
      def apply_template(name, locals)
        template = Location[settings.views] + name + ".erb"
        last_modified template.mtime
        erb name, :locals => locals
      end

      def save_referer
        session[:referer] = request.fullpath
      end

      def go_back(default_path)
        if referer = session[:referer]
          session[:referer] = nil
          redirect session[:referer]
        else
          redirect default_path
        end
      end
    end

    # `WebClient::Application` is a sinatra application.
    class Application < Sinatra::Base
      include ApplicationUtil

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

      # Go login page if the user is not logined.
      before do
        unless request.path_info == "/login"
          unless session[:email]
            save_referer
            redirect '/login'
          end
        end
      end

      #
      # login
      #

      # Show login page.
      get '/login' do
        unless session[:email]
          apply_template :login
        else
          redirect '/'
        end
      end

      # Process authentications.
      post '/login' do
        user = User.new(params[:email], Global.workspace_root)

        case params[:submit_type]
        when "login"
          if user.auth(params[:password])
            session[:email] = params[:email]

            go_back('/')
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

            # go to previous page
            go_back('/')
          else
            session[:message] = "The account exists already."
          end
        end

        redirect '/login'
      end

      # Logout the user.
      get '/logout' do
        session[:email] = nil
        redirect '/login'
      end

      #
      # main page
      #

      # Show workspace page. This page should be not cached.
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

      # Show a job management page.
      get '/job/:job_id' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])

        apply_template(:job, {:job => job})
      end

      # Delete the job and go home.
      get '/job/delete/:job_id' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])

        # delete the job if it exists
        job.delete if job.exist?

        # go workspace
        redirect '/'
      end

      #
      # upload
      #

      post '/upload/ppg/:job_id' do
        filename = params[:file][:filename]
        filepath = params[:file][:tempfile].path

        if handler = Global.job_queue.find_handler(params[:job_id])
          handler.upload_ppg(filename, filepath)
        else
          return 404, "No such job found."
        end
      end

      post '/upload/file/:job_id' do
        filename = params[:file][:filename]
        filepath = params[:file][:tempfile].path

        if handler = Global.job_queue.find_handler(params[:job_id])
          req.upload_file(filename, filepath)
        else
          return 404, "No such job found."
        end
      end

      #
      # target files
      #

      # Send the processing result zip file of the session.
      get '/result/:job_id/:filename' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])
        location = job.result(params[:filename])

        if job.exist? and location.exist?
          content_type "application/zip"
          last_modified zip_location.mtime

          send_file(zip_location.path.to_s)
        else
          return 404, "No such results"
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

      #
      # Websocket event handlers
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
    end
  end
end
