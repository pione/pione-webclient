require 'em-websocket'
require 'thread'

module Pione
  class Job < StructX
    member :uuid
    member :package
    member :location

    def execution_result(e)
      if e.kind_of?(SystemExit)
        if e.success?
          return :succeeded
        else
          return :failed
        end
      else
        e.to_s
      end
    end

    def to_json(*args)
      {uuid: uuid, name: package.name, location: package.location}
    end
  end

  JOB_QUEUE = Queue.new

  class JobHistory
    def initialize(loaction)
      @location = location
    end

    def push(job, status)
      File.open("a") do |file|
        file.puts JSON.generate(job)
      end
    end
  end

  class JobExecuter
    def start
      EventMachine.run &execute
    end

    def execute
      job = JOB_QUEUE.pop
      PioneClient.run job.client_options
    rescue SystemExit => e
      job.execution_result(e)
      HISTORY.push(job)
    end
  end
end


