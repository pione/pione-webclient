module Pione
  module Webclient
    module ApplicationUtil
      def logined?
        not(session[:email].nil?)
      end

      def user
        User.new(session[:email], Global.workspace_root)
      end

      def workspace
        Workspace.new(Global.workspace_root)
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
      register Sinatra::MultiRoute

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

        if params[:password] != params[:confirmation]
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
        job.desc = params[:job_desc]

        unless job.exist?
          job.save
        end

        redirect '/job/manage/' + job.id
      end

      # Show a job management page.
      get '/job/manage/:job_id' do
        job = Job.new(user, params[:job_id])

        # show management page
        apply_template(:job, {:job => job})
      end

      get '/job/requestable/:job_id' do
        job = Job.new(user, params[:job_id])
        job.requestable?.to_json
      end

      get '/job/sources/:job_id' do
        job = Job.new(user, params[:job_id])

        return {ppg: job.ppg_filename, sources: job.find_sources}.to_json
      end

      # Delete the job and go home.
      get '/job/delete/:job_id' do
        job = Job.new(user, params[:job_id])

        # delete the job if it exists
        job.delete if job.exist?

        # go workspace
        redirect '/'
      end

      post '/job/upload-by-file/:input_type/:job_id' do
        job = Job.new(user, params[:job_id])

        filename = URI.unescape(params[:file][:filename])
        filepath = params[:file][:tempfile].path

        if job.exist?
          case params[:input_type]
          when "ppg"
            job.upload_ppg_by_file(filename, filepath)
          when "source"
            job.upload_source_by_file(filename, filepath)
          else
            return 404, "Unknown input type."
          end
          return 200, "Uploaded."
       else
          return 404, "No such job found."
        end
      end

      post '/job/upload-by-url/:job_id' do
        job = Job.new(user, params[:job_id])

        if job.exist?
          case params[:input_type]
          when "ppg"
            job.upload_ppg_by_url(params[:filename], params[:url])
          when "source"
            job.upload_source_by_url(params[:filename], params[:url])
          else
            return 404, "Unknown input type."
          end
          return 200, "Queued."
        else
          return 404, "No such job found."
        end
      end

      get '/job/request/:job_id' do
        job = workspace.find_job(params["job_id"])

        if job
          Global.job_queue.request(job)
          return 200, "Request has been queued."
        else
          return 404, "No such job found."
        end
      end

      get '/job/clear/:job_id' do
        job = workspace.find_job(params["job_id"])

        if job
          job.clear_base_location
          return 200, "Request has been queued."
        else
          return 404, "No such job found."
        end
      end

      # Send the job result zip file of the session.
      get '/job/result/:job_id/:filename' do
        job = Job.new(user, params[:job_id])

        zip = job.results_location + params[:filename]

        if job.exist? and zip.exist?
          content_type "application/zip"
          last_modified zip.mtime

          send_file(zip.path.to_s)
        else
          return 404, "No such results."
        end
      end

      #
      # Interactive Operation
      #

      route(:get, :post, %r{/interactive/(\w+)/(\w+)(.+)}) do |job_id, interaction_id, path|
        manager = Global.interactive_operation_manager

        # default action is get
        params[:action] ||= "get"

        # check the interaction
        unless manager.known?(job_id, interaction_id)
          return 404, "No such interaction exists."
        end

        if params[:action]
          case params[:action]
          when "finish"
            manager.operation_finish(job_id, interaction_id, params[:result] || "")
            return 200, "The interaction has finished. Please go back to the job management page."

          when "get"
            if data = manager.operation_get(job_id, interaction_id, path)
              file = Location[Temppath.mkdir] + path
              file.write(data)
              send_file(file.path.to_s)
            else
              return 404, "file not found"
            end

          when "create"
            if params[:content]
              if manager.operation_create(job_id, interaction_id, path, content)
                return 200, "The operation 'create' has succeeded."
              else
                return 500, "The operation 'create' has failed."
              end
            else
              return 400, "The operation 'create' requires the content."
            end

          when "delete"
            if manager.operation_delete(job_id, interaction_id, path)
              return 200, "The operation 'delete' has succeeded."
            else
              return 500, "The operation 'delete' has failed."
            end

          when "list"
            list = manager.operation_list(job_id, interaction_id, path)
            if list.nil?
              return 500, "The operation 'list' has failed."
            end

            if list
              return list.to_json
            else
              return 404, "Cannot list."
            end

          else
            return 400, "This operation is invalid."
          end
        end
      end

      #
      # Admin
      #

      # Show administration page.
      get '/admin' do
        apply_template(:admin, users: workspace.find_users)
      end

      # Set the configuration.
      post '/admin/conf' do
        current_workspace = workspace
        current_workspace.title = params[:workspace_title]
        current_workspace.save
        redirect '/admin'
      end

      # Delete the user.
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

      Global.io.on("join-job") do |data, client|
        Global.websocket_manager.add(data["job_id"], client.session)
      end

      Global.io.on("disconnect") do |client|
        Global.websocket_manager.clean(client.session)
      end

      # Cancel the job.
      Global.io.on("cancel") do |data, client|
        job = workspace.find_job(data["job_id"])
        Global.job_queue.cancel(job)
      end

      # finish interactive operation
      Global.io.on("finish-interactive-operation") do |data, client|
        Global.interactive_operation_manager.finish(data["job_id"], data)
      end
    end
  end
end
