Thread.abort_on_exception = true

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/rocketio'

require 'pione'
require 'pione/global/webclient-variable'
require 'pione/log/webclient-message-log-receiver'
require 'pione/front/webclient-front'
require 'pione/command/pione-webclient'
require 'pione/webclient/webclient-exception'
require 'pione/webclient/job-manager'
require 'pione/webclient/application'

#
# presence_notification_address
#

if ENV["PRESENCE_NOTIFICATION_ADDRESS"]
  Pione::Global.presence_notification_address = ENV["PRESENCE_NOTIFICATION_ADDRESS"]
end
