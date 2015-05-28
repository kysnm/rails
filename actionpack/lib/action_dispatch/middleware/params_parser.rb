require 'active_support/core_ext/hash/conversions'
require 'action_dispatch/http/request'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  class ParamsParser
    class ParseError < StandardError
      attr_reader :original_exception

      def initialize(message, original_exception)
        super(message)
        @original_exception = original_exception
      end
    end

    DEFAULT_PARSERS = { Mime::JSON => :json }

    def initialize(parsers = {})
      @parsers = DEFAULT_PARSERS.merge(parsers)
    end

    def start_request(req, res)
      if params = parse_formatted_parameters(req)
        req.set_header "action_dispatch.request.request_parameters", params
      end
    end

    def finish_request(req, res)
    end

    private
      def parse_formatted_parameters(request)
        return false if request.content_length.zero?

        strategy = @parsers[request.content_mime_type]

        return false unless strategy

        case strategy
        when Proc
          strategy.call(request.raw_post)
        when :json
          data = ActiveSupport::JSON.decode(request.raw_post)
          data = {:_json => data} unless data.is_a?(Hash)
          Request::Utils.deep_munge(data).with_indifferent_access
        else
          false
        end
      rescue => e # JSON or Ruby code block errors
        logger(request).debug "Error occurred while parsing request parameters.\nContents:\n\n#{request.raw_post}"

        raise ParseError.new(e.message, e)
      end

      def logger(req)
        req.get_header('action_dispatch.logger') || ActiveSupport::Logger.new($stderr)
      end
  end
end
