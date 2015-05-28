module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if ActiveRecord::Base.connected?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if ActiveRecord::Base.connected?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def start_request(req, res)
      connection    = ActiveRecord::Base.connection
      connection.enable_query_cache!
    end

    def finish_request(req, res)
      connection    = ActiveRecord::Base.connection
      enabled       = connection.query_cache_enabled
      connection_id = ActiveRecord::Base.connection_id

      restore_query_cache_settings(connection_id, enabled)
    end

    private

    def restore_query_cache_settings(connection_id, enabled)
      ActiveRecord::Base.connection_id = connection_id
      ActiveRecord::Base.connection.clear_query_cache
      ActiveRecord::Base.connection.disable_query_cache! unless enabled
    end

  end
end
