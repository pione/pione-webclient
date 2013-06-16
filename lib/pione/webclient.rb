require 'pione'
require 'sinatra/base'
require 'sinatra/reloader'

require 'pione/webclient/processing-type'
require 'pione/webclient/application'

Pione::System::Global.define_item(
  :webclient_root, false, Location[File.dirname(__FILE__)] + ".." + ".."
)

#
# variables
#

$client_watcher = {}
$client_watcher_lock = Mutex.new
if ENV["PRESENCE_NOTIFICATION_ADDRESS"]
  $presence_notification_address = ENV["PRESENCE_NOTIFICATION_ADDRESS"]
end
puts $presence_notification_address

#
# utility functions
#

# stop client process
def stop_client_process(session)
  if client_address = session['client-address']
    client = DRbObject.new_with_uri(client_address)
    begin
      timeout(1) {client.terminate}
    rescue
      # ignore
    end
  end
end

# start client process
def call_client_process(session, document_path, params, output, input)
  pione_client_name = Util::UUID.generate
  args = ["pione-client", document_path]
  args << "--name" << pione_client_name
  args << "--task-worker" << "0"
  args << "--params" << params if params
  args << "--output" << output if output
  args << "--input" << input if input
  if $presence_notification_address
    args << "--presence-notification-address" << $presence_notification_address
  end
  pid = Process.spawn(*args)
  thread = Process.detach(pid)
  $client_watcher_lock.synchronize do
    $client_watcher[session["uuid"]] = thread
  end
  sleep 1
  ### find the client
  address = nil
  # avoid connection trouble
  DRb::DRbConn.clear_table
  Global.client_front_port_range.each do |port|
    begin
      address = "druby://%s:%s" % [Global.my_ip_address, port]
      client = DRbObject.new_with_uri(address)
      if client.name == pione_client_name
        session["base-uri"] = client.tuple_space_server.base_uri.to_s
        break
      end
    rescue
      address = nil
    end
  end
  return address
end

# check client process
def check_client_process(session)
  $client_watcher_lock.synchronize do
    return unless $client_watcher[session["uuid"]]
    if not($client_watcher[session["uuid"]].alive?)
      session['process-status'] = :finished
    end
  end
end

