require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/object/blank'
require 'active_support/log_subscriber'
require 'action_dispatch/http/request'
require 'rack/body_proxy'

module Rails
  module Rack
    # Sets log tags, logs the request, calls the app, and flushes the logs.
    #
    # Log tags (+taggers+) can be an Array containing: methods that the +request+
    # object responds to, objects that respond to +to_s+ or Proc objects that accept
    # an instance of the +request+ object.
    class Logger < ActiveSupport::LogSubscriber
      def initialize(taggers = nil)
        @taggers      = taggers || []
      end

      def new; self; end

      def start_request(request, res)
        if logger.respond_to?(:tagged)
          logger.tagged(compute_tags(request)) { call_app(request) }
          call_app request
        end
      end

      def finish_request(req, res)
        if logger.respond_to?(:tagged)
          finish req
          ActiveSupport::LogSubscriber.flush_all!
        end
      end

    protected

      def call_app(request)
        # Put some space between requests in development logs.
        if development?
          logger.debug ''
          logger.debug ''
        end

        instrumenter = ActiveSupport::Notifications.instrumenter
        instrumenter.start 'request.action_dispatch', request: request
        logger.info { started_request_message(request) }
      end

      # Started GET "/session/new" for 127.0.0.1 at 2012-09-26 14:51:42 -0700
      def started_request_message(request)
        'Started %s "%s" for %s at %s' % [
          request.request_method,
          request.filtered_path,
          request.ip,
          Time.now.to_default_s ]
      end

      def compute_tags(request)
        @taggers.collect do |tag|
          case tag
          when Proc
            tag.call(request)
          when Symbol
            request.send(tag)
          else
            tag
          end
        end
      end

      private

      def finish(request)
        instrumenter = ActiveSupport::Notifications.instrumenter
        instrumenter.finish 'request.action_dispatch', request: request
      end

      def development?
        Rails.env.development?
      end

      def logger
        Rails.logger
      end
    end
  end
end
