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

      #
      # settings
      #

      set :server, 'thin'
      set :port, Global.webclient_port
      set :public_folder, Global.webclient_root + 'public'
      use Rack::CommonLogger

      enable :sessions
      register Sinatra::RocketIO
      register Sinatra::MultiRoute

      configure :development do
        register Sinatra::Reloader
      end

      # Go login page if the user is not logined.
      before do
        if request.path_info.start_with?("/job", "/workspace", "/admin", "/user", "/interactive")
          unless logined?
            save_referer
            redirect '/login'
          end
        end
      end

      get '/' do
        redirect '/workspace'
      end

      #
      # login
      #

      # Show login page.
      get '/login' do
        not(logined?) ? apply_template(:login) : redirect('/workspace')
      end

      # Process authentications.
      post '/login' do
        new_user = User.new(params[:email], Global.workspace_root)

        if new_user.auth(params[:password])
          session[:email] = params[:email]

          go_back('/workspace')
        else
          session[:message] = "Login failed because of no such user or bad password."
        end

        redirect '/login'
      end

      # Show signup page.
      get '/signup' do
        not(logined?) ? apply_template(:signup) : redirect('/workspace')
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
            go_back('/workspace')
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
      get '/workspace' do
        jobs = user.find_jobs

        erb :workspace, :locals => {:jobs => jobs}
      end

      # Return all jobs for the user as a JSON data
      get '/workspace/jobs' do
        jobs = user.find_jobs

        { :id => job.id,
          :desc => job.desc,
          :ctime => job.ctime,
          :mtime => job.mtime,
          :status => job.status,
        }.to_json
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
        job = workspace.find_job(params[:job_id])

        # show management page
        apply_template(:job, {:job => job})
      end

      get '/job/requestable/:job_id' do
        job = workspace.find_job(params[:job_id])
        job.requestable?.to_json
      end

      get '/job/sources/:job_id' do
        job = Job.new(user, params[:job_id])

        if job.exist?
          if job.ppg_filename and ppg = job.ppg_file(job.ppg_filename)
            return {
              ppg: {
                filename: ppg.basename,
                size: ppg.size,
                mtime: ppg.mtime.iso8601},
              sources: job.find_sources.map{|filename|
                source = job.source_file(filename)
                { filename: filename,
                  size: source.size,
                  mtime: source.mtime.iso8601}}
            }.to_json
          else
            return {
              sources: job.find_sources.map{|filename|
                source = job.source_file(filename)
                { filename: filename,
                  size: source.size,
                  mtime: source.mtime.iso8601}}}.to_json
          end
        else
          return 404, "No such job found."
        end
      end

      # Delete the job and go home.
      get '/job/delete/:job_id' do
        job = workspace.find_job(params[:job_id])

        # delete the job if it exists
        job.delete if job.exist?

        # go workspace
        redirect '/workspace'
      end

      post '/job/upload-by-file/:input_type/:job_id' do
        job = workspace.find_job(params[:job_id])

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
        job = workspace.find_job(params[:job_id])

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

      get '/job/input/get/:job_id/:type/:filename' do
        job = workspace.find_job(params[:job_id])
        file = nil

        if job.exist?
          case params[:type]
          when "ppg"
            file = job.ppg_file(params[:filename])
          when "source"
            file = job.source_file(params[:filename])
          end

          if file
            return send_file(file.path)
          else
            return 404, "The file doesn't exist."
          end
        else
          return 404, "No such job found."
        end
      end

      get '/job/input/delete/:job_id/:type/:filename' do
        job = workspace.find_job(params[:job_id])

        if job.exist?
          case params[:type]
          when "ppg"
            job.delete_ppg(params[:filename])
          when "source"
            job.delete_source(params[:filename])
          else
            return 404, "Unknown input type."
          end
          return 200, "The input file has deleted."
        else
          return 404, "No such job found."
        end
      end

      get '/job/request/:job_id' do
        job = workspace.find_job(params[:job_id])

        if job
          Global.job_queue.request(job)
          return 200, "Request has been queued."
        else
          return 404, "No such job found."
        end
      end

      get '/job/cancel/:job_id' do
        job = workspace.find_job(params[:job_id])

        if job
          if Global.job_queue.cancel(job)
            return 200, "The job has been canceled."
          else
            return 404, "The job is not processing."
          end
        else
          return 404, "No souch job found."
        end
      end

      get '/job/clear/:job_id' do
        job = workspace.find_job(params[:job_id])

        if job
          job.clear_base_location
          return 200, "Request has been queued."
        else
          return 404, "No such job found."
        end
      end

      # Send the job result zip file of the session.
      get '/job/result/:job_id/:filename' do
        job = workspace.find_job(params[:job_id])

        zip = job.result_location + params[:filename]

        if job.exist? and zip.exist?
          content_type "application/zip"
          last_modified zip.mtime

          send_file(zip.path.to_s)
        else
          return 404, "No such results."
        end
      end

      post '/job/desc/:job_id' do
        job = workspace.find_job(params[:job_id])

        if job.exist?
          job.desc = params[:text]
          job.save
          return 200, "Job description has updated."
        else
          return 404, "No souch job found."
        end
      end

      #
      # Interactive Operation
      #

      route(:get, :post, %r{/interactive/([\w-]+)/([\w-]+)/(.*)}) do |job_id, interaction_id, path|
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
            cgi_info = Util::CGIInfo.new

            # meta-variables
            cgi_info.auth_type = env['AUTH_TYPE']
            cgi_info.content_length = request.content_length
            cgi_info.content_type = request.content_type
            cgi_info.path_info = env['PATH_INFO']
            cgi_info.query_string = env['QUERY_STRING']
            cgi_info.remote_addr = env['REMOTE_ADDR']
            cgi_info.remote_host = env['REMOTE_HOST']
            cgi_info.remote_ident = env['REMOTE_IDENT']
            cgi_info.remote_user = user.name
            cgi_info.request_method = env['REQUEST_METHOD']
            cgi_info.script_name = env['SCRIPT_NAME']
            cgi_info.server_name = env['SERVER_NAME']
            cgi_info.server_port = env['SERVER_PORT']
            cgi_info.server_protocol = env['SERVER_PROTOCOL']

            # http sepcific variables
            env.each do |key, val|
              if key.start_with?("HTTP_")
                cgi_info.http_header[key] = val
              end
            end

            # body
            request.body.rewind
            cgi_info.body = request.body.read

            if data = manager.operation_get(job_id, interaction_id, path, cgi_info)
              if data.kind_of?(Util::CGIResponse)
                if data.nph?
                  # how?
                else
                  if not(data.location.nil?)
                    redirect data.location
                  else
                    content_type data.content_type
                    return data.status_code, data.body
                  end
                end
              else
                file = Location[Temppath.mkdir] + path
                file.write(data)
                send_file(file.path.to_s)
              end
            else
              return 404, "file not found"
            end

          when "create"
            if params[:content]
              if manager.operation_create(job_id, interaction_id, path, params[:content])
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
    end
  end
end
