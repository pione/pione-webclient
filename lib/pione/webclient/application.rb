module Pione
  module Webclient
    module ApplicationUtil
      def logined?
        not(session[:email].nil?)
      end

      def user
        User.new(session[:email], Global.workspace_root)
      end

      def apply_template(name, locals={})
        template = Location[settings.views] + (name.to_s + ".erb")
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

    module ViewUtil
      def view_header
        erb :header
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
        unless request.path_info == "/login" or request.path_info == "/signup"
          unless logined?
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
        not(logined?) ? apply_template(:login) : redirect('/')
      end

      # Process authentications.
      post '/login' do
        new_user = User.new(params[:email], Global.workspace_root)

        if new_user.auth(params[:password])
          session[:email] = params[:email]

          go_back('/')
        else
          session[:message] = "Login failed because of no such user or bad password."
        end

        redirect '/login'
      end

      # Show signup page.
      get '/signup' do
        not(logined?) ? apply_template(:signup) : redirect('/')
      end

      # Process sign up.
      post '/signup' do
        new_user = User.new(params[:email], Global.workspace_root)
        workspace = Workspace.new(Global.workspace_root)

        if params[:password] == params[:confirmation]
          session[:message] = "The password and confirmation are mismatched."
        else
          unless new_user.exist?
            # save user informations
            new_user.set_password(params[:password])
            new_user.set_admin(workspace.find_users.size == 0)
            new_user.save

            # store the user informations to session
            session[:email] = params[:email]

            # go to previous page
            go_back('/')
          else
            session[:message] = "The account exists already."
          end
        end

        redirect '/signup'
      end

      # Logout the user.
      get '/logout' do
        session[:email] = nil
        redirect '/login'
      end

      #
      # workspace routes
      #

      # Show workspace page. This page should be not cached.
      get '/' do
        jobs = user.find_jobs

        erb :workspace, :locals => {:jobs => jobs}
      end

      #
      # job routes
      #

      # Create a new job.
      post '/job/create' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, nil)
        job.name = params[:job_name]

        unless job.exist?
          job.save
        end

        redirect '/job/manage' + job.id
      end

      # Show a job management page.
      get '/job/manage/:job_id' do
        job = Job.new(user, params[:job_id])

        apply_template(:job, {:job => job})
      end

      # Delete the job and go home.
      get '/job/delete/:job_id' do
        job = Job.new(user, params[:job_id])

        # delete the job if it exists
        job.delete if job.exist?

        # go workspace
        redirect '/'
      end

      post '/job/upload/ppg/:job_id' do
        filename = params[:file][:filename]
        filepath = params[:file][:tempfile].path

        if handler = Global.job_queue.find_handler(params[:job_id])
          handler.upload_ppg(filename, filepath)
        else
          return 404, "No such job found."
        end
      end

      post '/job/upload/file/:job_id' do
        filename = params[:file][:filename]
        filepath = params[:file][:tempfile].path

        if handler = Global.job_queue.find_handler(params[:job_id])
          req.upload_file(filename, filepath)
        else
          return 404, "No such job found."
        end
      end

      # Send the job result zip file of the session.
      get '/job/result/:job_id/:filename' do
        user = User.new(session[:email], Global.workspace_root)
        job = Job.new(user, params[:job_id])
        location = job.results_dir + params[:filename]

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

      get '/admin' do
        workspace = Workspace.new(Global.workspace_root)

        apply_template(:admin, users: workspace.find_users)
      end

      get '/admin/user/delete/:user_name' do
        if user.exist?
          user.delete
        end

        redirect '/admin'
      end

      get '/admin/shutdown' do
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
