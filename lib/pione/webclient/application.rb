module Pione
  module Webclient
    module APIInterface
      def define_operation_api(path, &b)
        route(:get, :post, path, &b)
      end

      def define_post_only_operation_api(path, &b)
        route(:post, path, &b)
      end
    end

    module ApplicationUtil
      def logined?
        not(session[:username].nil?)
      end

      def encodeURI(str)
        URI.encode_www_form_component(str)
      end

      def myself
        User.new(session[:username], workspace)
      end

      def workspace
        @__workspace__ ||= Workspace.new(Global.workspace_root)
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

      def create_job_data(job)
        return {
          id: job.id,
          desc: job.desc,
          ctime: job.ctime.iso8601,
          mtime: job.mtime.iso8601,
          ppg: job.ppg_filename,
          inupts: job.find_inputs,
          status: job.status,
        }
      end

      def jobs_to_json(jobs)
        jobs.map{|job| create_job_data(job)}.to_json
      end

      def job_to_json(job)
        create_job_data(job).to_json
      end

      def create_file_data(location)
        return {
          filename: location.basename,
          size: location.size,
          mtime: location.mtime.iso8601,
        }
      end

      def file_to_json(location)
        create_file_data(location).to_json
      end

      def files_to_json(locations)
        locations.map{|location| create_file_data(location)}.to_json
      end

      def create_user_data(user)
        return {
          name: user.name,
          ctime: user.ctime,
          mtime: user.mtime,
          admin: user.admin?
        }
      end

      def user_to_json(user)
        create_user_data(user).to_json
      end

      def users_to_json(users)
        users.map{|user| create_user_data(user)}.to_json
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

      register APIInterface

      PROTECTED_PAGES = [
        "/page/job",
        "/page/workspace",
        "/page/admin",
        "/job",
        "/workspace",
        "/admin",
        "/user",
        "/interactive",
      ]

      # Go login page if the user is not logined.
      before do
        if request.path_info.start_with?(*PROTECTED_PAGES)
          unless logined?
            save_referer
            redirect '/page/login'
          end
        end
      end

      get '/' do
        if logined?
          redirect '/page/workspace/' + encodeURI(myself.name)
        else
          redirect '/page/login'
        end
      end

      #
      # login
      #

      # Show login page.
      get '/page/login' do
        not(logined?) ? apply_template(:login) : redirect('/page/workspace' + encodeURI(myself.name))
      end

      # Show signup page.
      get '/page/signup' do
        not(logined?) ? apply_template(:signup) : redirect('/page/workspace')
      end

      # Process authentications. This is operation API.
      define_post_only_operation_api('/auth/login/:username') do
        new_user = User.new(params[:username], workspace)

        if new_user.auth(params[:password])
          session[:username] = params[:username]

          return 200, "You have logged in."
        else
          return 403, "Login failed."
        end
      end

      # Process sign up.
      define_post_only_operation_api('/auth/signup/:username') do
        new_user = User.new(params[:username], workspace)

        unless new_user.exist?
          # save user informations
          if new_user.set_password(params[:password])
            new_user.save

            # first user of this workspace is authorized as an administrator
            unless workspace.admins.size > 0
              workspace.admins << new_user.name
              workspace.save
            end

            # store the user informations to session
            session[:username] = params[:username]

            # go to previous page
            return 200, "You have signed up."
          else
            return 404, "Bad password."
          end
        else
          session[:message] = "The account exists already."
          return 403, "The user exists already."
        end
      end

      # Logout the user.
      define_operation_api('/auth/logout') do
        session[:username] = nil
        redirect '/page/login'
      end

      #
      # workspace routes
      #

      # Show workspace page. This page should be not cached.
      get '/page/workspace/:username' do
        user = User.new(params[:username], workspace)
        if myself.name == user.name or myself.admin?
          erb :workspace, :locals => {:user => user}
        else
          return 403, "Cannot show workspace of the user because of your permission."
        end
      end

      # Set title of the workspace.
      define_operation_api('/workspace/title/set') do
        if myself.admin?
          if params[:text]
            workspace.title = params[:text]
            workspace.save
            return 200, "Workspace title has been updated."
          else
            return 403, "Workspace title is required."
          end
        else
          return 403, "Cannot update because of your permission."
        end
      end

      # Return all users as a JSON data.
      define_operation_api('/workspace/users/info') do
        if myself.admin?
          return users_to_json(workspace.find_users)
        else
          return 403, "Cannot get user informations because of your permission."
        end
      end

      # Return all jobs for the user as a JSON data.
      define_operation_api('/workspace/jobs/info/:username') do
        if params[:username] == myself.name or myself.admin?
          target_user = User.new(params[:username], workspace)
          return jobs_to_json(target_user.find_jobs)
        else
          return 403, "Cannot get job informations because of your permission."
        end
      end

      #
      # user
      #

      define_operation_api('/user/delete/:username') do
        user = User.new(params[:username], workspace)

        if user.exist? and (user.name == myself.name or myself.admin?)
          user.delete
          return 200, "The user has been deleted."
        else
          return 403, "Cannot delete the user."
        end
      end

      #
      # job
      #

      # Show a job management page.
      get '/page/job/:job_id' do
        job = workspace.find_job(params[:job_id])

        if job
          # show management page
          apply_template(:job, {:job => job})
        else
          return 404, "No such job found."
        end
      end

      # Create a new job.
      define_operation_api('/job/create') do
        job = Job.new(myself, nil)
        job.desc = params[:desc]

        unless job.exist?
          job.save
          return job_to_json(Job.new(myself, job.id))
        else
          return 500, "The job exists already."
        end
      end

      # Update description of the job.
      define_operation_api('/job/desc/set/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job.exist?
          job.desc = params[:text]
          job.save
          return 200, "Job description has updated."
        else
          return 404, "No souch job found."
        end
      end

      # Get the job informations.
      define_operation_api('/job/info/:job_id') do
        job = workspace.find_job(params[:job_id])
        if job
          return job_to_json(job)
        else
          return 404, "The job not found."
        end
      end

      # Delete the job.
      define_operation_api('/job/delete/:job_id') do
        job = workspace.find_job(params[:job_id])

        # delete the job if it exists
        if job
          if not(job.processing?)
            job.delete
            return 200, "The job has been deleted."
          else
            return 403, "Failed to delete the job because of the state 'processing'."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/ppg/info/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          if job.ppg_filename and ppg = job.ppg_file(job.ppg_filename)
            return file_to_json(ppg)
          else
            return 404, "No such file found."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/ppg/get/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          file = job.ppg_file(params[:filename])

          if file
            return send_file(file.path)
          else
            return 404, "The file doesn't exist."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/ppg/delete/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if not(job.processing?)
            job.delete_ppg(params[:filename])
            return 200, "The ppg file has deleted."
          else
            return 403, "Cannot delete the ppg file because the job is processing."
          end
        else
          return 404, "No such job found."
        end
      end

      # Upload a package or an input by file.
      define_operation_api('/job/ppg/upload/file/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        filename = params[:filename]
        filepath = params[:file][:tempfile].path

        if job
          if not(job.processing?)
            job.upload_ppg_by_file(filename, filepath)
            return 200, "Uploaded."
          else
            return 403, "Cannot upload the file because the job is processing."
          end
        else
          return 404, "No such job found."
        end
      end

      # Upload a package or an input by URL.
      define_operation_api('/job/ppg/upload/url/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if not(job.processing?)
            job.upload_ppg_by_url(params[:filename], params[:url])
            return 200, "Queued."
          else
            return 403, "Cannot upload the file because the job is processing."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/inputs/info/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          return files_to_json(job.find_inputs)
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/inputs/upload/result/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          if params[:url]
            uri = URI.parse(params[:url])

            if uri.host.downcase == request.host.downcase and uri.port.to_s == request.port.to_s
              if md = %r{^/job/result/get/([0-9a-f-]+)/([^/]+)$}.match(uri.path)
                result_job_id = md[1]
                result_filename = md[2]
                if _job = workspace.find_job(result_job_id)
                  zip = _job.result_file(result_filename)
                else
                  return 404, "No such job found."
                end
              else
                return 403, "Bad URL."
              end
            else
              zip = Location[params[:url]]
            end

            dir = Location[Temppath.mkdir]
            Util::Zip.uncompress(zip, dir)
            if (dir + "output").exist?
              (dir + "output").entries.each do |entry|
                if entry.file?
                  entry.copy(job.input_location + entry.basename)
                end
              end
              return 200, "Input files are uploaded from the result zip file."
            else
              return 403, "Bad result file."
            end
          else
            return 403, "URL is required."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/input/info/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if file = job.input_file(params[:filename])
            return file_to_json(file)
          else
            return 404, "No such file found."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/input/get/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if file = job.input_file(params[:filename])
            return send_file(file.path)
          else
            return 404, "The file doesn't exist."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/input/delete/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if not(job.processing?)
            job.delete_input(params[:filename])
            return 200, "The input file has deleted."
          else
            return 403, "Cannot delete the file because the job is processing."
          end
        else
          return 404, "No such job found."
        end
      end

      # Upload a package or an input by file.
      define_operation_api('/job/input/upload/file/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        filename = params[:filename]
        filepath = params[:file][:tempfile].path

        if job
          if not(job.processing?)
            job.upload_input_by_file(filename, filepath)
            return 200, "Uploaded."
          else
            return 403, "Cannot upload the file because the job is processing."
          end
       else
          return 404, "No such job found."
        end
      end

      # Upload an input by URL.
      define_operation_api('/job/input/upload/url/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if not(job.processing?)
            job.upload_input_by_url(params[:filename], params[:url])
            return 200, "Queued."
          else
            return 403, "Cannot upload the file because the job is processing."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/start/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          if job.processable?
            Global.job_queue.request(job)
            return 200, "Request has been queued."
          else
            return 403, "The job is not processable."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/stop/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          if Global.job_queue.cancel(job)
            return 200, "The job has been canceled."
          else
            return 403, "The job is not processing."
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/clear/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          if not(job.processing?)
            job.clear_base_location
            return 200, "Request has been queued."
          else
            return 403, 'Cannot clear the base directory because of the job status "%s".' % job.status
          end
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/results/info/:job_id') do
        job = workspace.find_job(params[:job_id])

        if job
          return files_to_json(job.find_results)
        else
          return 404, "No such job found."
        end
      end

      define_operation_api('/job/result/info/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])

        if job
          if result = result_file(params[:filename])
            return result_to_json(result)
          else
            return 404, "No such result."
          end
        else
          return 404, "No such result."
        end
      end

      # Send the job result zip file of the session.
      define_operation_api('/job/result/get/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])
        result = job.result_location + params[:filename]

        if job.exist? and result.exist?
          content_type "application/zip"
          last_modified result.mtime

          send_file(result.path.to_s)
        else
          return 404, "No such result."
        end
      end

      # Send the job result zip file of the session.
      define_operation_api('/job/result/delete/:job_id/:filename') do
        job = workspace.find_job(params[:job_id])
        result = job.result_location + params[:filename]

        if job.exist? and result.exist?
          result.delete
          return 200, "The result file has been deleted."
        else
          return 404, "No such result."
        end
      end

      #
      # Admin
      #

      # Show administration page.
      get '/page/admin' do
        if myself.admin?
          apply_template(:admin)
        else
          return 403, "Cannot access the page for your permission."
        end
      end

      define_operation_api('/admin/add/:username') do
        if myself.admin?
          user = User.new(params[:username], workspace)

          if user.exist?
            user.admin = true
            user.save
            return 200, "The user is authorized as an administrator."
          else
            return 404, "No such user found."
          end
        else
          return 403, "Cannot do it because you are not administrator."
        end
      end

      define_operation_api('/admin/delete/:username') do
        if myself.admin?
          if user.exist?
            user.admin = false
            user.save
            return 200, "The user is deleted the authority of administrator."
          else
            return 404, "No such user found."
          end
        else
          return 403, "Cannot do it because you are not administrator."
        end
      end

      define_operation_api('/admin/shutdown') do
        if myself.admin?
          Global.io.push(:status, "SHUTDOWN")
          sleep 5
          puts "!!! PIONE Webclient shutdowned !!!"
          exit!
        else
          return 403, "Cannot do it because you are not administrator."
        end
      end

      #
      # Interactive Operation
      #

      route(:get, :post, %r{/interactive/([\w-]+)/([\w-]+)/(.*)}) do |job_id, interaction_id, path|
        manager = Global.interactive_operation_manager

        # default action is get
        params["pione-action"] ||= "get"

        # check the interaction
        unless manager.known?(job_id, interaction_id)
          return 404, "No such interaction exists."
        end

        if params["pione-action"]
          case params["pione-action"]
          when "finish"
            status = params["pione-status"] || "success"
            if status == "success" or status == "failure"
              manager.operation_finish(job_id, interaction_id, params["pione-result"] || "", status)
              return 200, "The interaction has finished. Please go back to the job management page."
            else
              return 400, ("\"%s\" is bad status." % status)
            end

          when "get"
            cgi_info = Util::CGIInfo.new

            # meta-variables
            cgi_info.auth_type = env['AUTH_TYPE']
            cgi_info.content_length = request.content_length
            cgi_info.content_type = request.content_type
            cgi_info.path_info = env['PATH_INFO']
            cgi_info.query_string = env['QUERY_STRING']
            cgi_info.remote_addr = env['REMOTE_ADDR']
            cgi_info.remote_host = env['REMOTE_HOST'] || env['REMOTE_ADDR']
            cgi_info.remote_ident = env['REMOTE_IDENT']
            cgi_info.remote_user = myself.name
            cgi_info.request_method = env['REQUEST_METHOD']
            cgi_info.script_name = request.script_name
            cgi_info.server_name = env['SERVER_NAME']
            cgi_info.server_port = env['SERVER_PORT']
            cgi_info.server_protocol = env['SERVER_PROTOCOL']

            # http sepcific variables
            env.each do |key, val|
              if key.start_with?("HTTP_")
                cgi_info.http_header[key.sub(/^HTTP_/, "")] = val
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
            if params["pione-content"]
              content = params["pione-content"]

              # read the content if it is a file
              if content.respond_to?(:has_key?) and content.has_key?(:tempfile)
                content = params["pione-content"][:tempfile].read
              end

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
            show_all = params["pione-show-all"] || "false"
            if show_all == "true" || show_all == "false"
              show_all = show_all == "true"
              list = manager.operation_list(job_id, interaction_id, path, show_all)
            else
              return 400, ('"%s" is invalid value for "pione-show-all"' % show_all)
            end

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
