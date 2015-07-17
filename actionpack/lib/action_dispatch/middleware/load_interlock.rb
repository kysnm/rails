require 'active_support/dependencies'
require 'rack/body_proxy'

module ActionDispatch
  class LoadInterlock
    def initialize
      @interlock = ActiveSupport::Dependencies.interlock
    end

    def start_request(req, res)
      @interlock.start_running
    end

    def finish_request(req, res)
      @interlock.done_running
    end
  end
end
