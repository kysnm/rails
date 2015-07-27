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

    DEFAULT_PARSERS = {
      Mime::JSON => lambda { |raw_post|
        data = ActiveSupport::JSON.decode(raw_post)
        data = {:_json => data} unless data.is_a?(Hash)
        Request::Utils.normalize_encode_params(data)
      }
    }

    def initialize(parsers = {})
      @parsers = DEFAULT_PARSERS.merge(parsers)
    end

    def start_request(req, res)
      default = req.get_header("action_dispatch.request.request_parameters") || {}
      params = parse_formatted_parameters(req, @parsers, default)
      req.set_header "action_dispatch.request.request_parameters", params
    end

    def finish_request(req, res)
    end

    private
      def parse_formatted_parameters(request, parsers, default)
        return default if request.content_length.zero?

        strategy = parsers.fetch(request.content_mime_type) { return default }

        strategy.call(request.raw_post)

      rescue => e # JSON or Ruby code block errors
        logger(request).debug "Error occurred while parsing request parameters.\nContents:\n\n#{request.raw_post}"

        raise ParseError.new(e.message, e)
      end

      def logger(req)
        req.get_header('action_dispatch.logger') || ActiveSupport::Logger.new($stderr)
      end
  end
end
