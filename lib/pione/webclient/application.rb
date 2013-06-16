module Pione
  module WebClient
    class Application< Sinatra::Base
      set :port, Global.relay_port
      set :public_folder, File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", 'public'))
      enable :sessions

      configure :development do
        register Sinatra::Reloader
      end

      #
      # common
      #
      before do
        check_client_process(session)
        session['uuid'] ||= Util::UUID.generate
      end

      #
      # main page
      #
      get '/' do
        send_file File.join(settings.public_folder, 'index.html')
      end

      #
      # process request handler
      #
      get '/processing-types' do
        content_type :json
        ProcessingType.read.map{|type| type.name}.to_json
      end

      # Request a job.
      post '/request' do
        
      end

      # Cancel the job.
      get '/cancel' do
        
      end
    end
  end
end
