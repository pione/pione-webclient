module Pione
  module Webclient
    class WebsocketManager
      def initialize
        @table = Hash.new
        @lock = Mutex.new
      end

      def add(job_id, connection_id)
        @lock.synchronize do
          unless @table.has_key?(job_id)
            @table[job_id] = Set.new
          end
          @table[job_id].add(connection_id)
        end
      end

      def delete(job_id, connection_id)
        @lock.synchronize do
          if @table.has_key?(job_id)
            @table[job_id].delete(connection_id)
            if @table[job_id].size == 0
              @table.delete(job_id)
            end
          end
        end
      end

      def clean(connection_id)
        @lock.synchronize do
          @table.values.each do |set|
            set.delete(connection_id)
          end
        end
      end

      def find(job_id)
        @lock.synchronize {return @table[job_id].to_a}
      end
    end
  end
end
