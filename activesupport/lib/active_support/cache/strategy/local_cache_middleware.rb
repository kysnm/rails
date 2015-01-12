require 'rack/body_proxy'
require 'rack/utils'

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache

        #--
        # This class wraps up local storage for middlewares. Only the middleware method should
        # construct them.
        class Middleware # :nodoc:
          attr_reader :name, :local_cache_key

          def initialize(name, local_cache_key)
            @name             = name
            @local_cache_key = local_cache_key
            @app              = nil
          end

          def new
            self
          end

          def start_request(req, res)
            LocalCacheRegistry.set_cache_for(local_cache_key, LocalStore.new)
          end

          def finish_request(req, res)
            LocalCacheRegistry.set_cache_for(local_cache_key, nil)
          end
        end
      end
    end
  end
end
