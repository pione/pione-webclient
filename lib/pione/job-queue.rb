require 'em-websocket'
require 'thread'

module Pione
  class Job < StructX
    member :uuid
    member :package_name
    member :location
  end


end


