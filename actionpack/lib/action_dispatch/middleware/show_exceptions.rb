require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls an exceptions app that will wrap it in a format for the end user.
  #
  # The exceptions app should be passed as parameter on initialization
  # of ShowExceptions. Every time there is an exception, ShowExceptions will
  # store the exception in env["action_dispatch.exception"], rewrite the
  # PATH_INFO to the exception status code and call the rack app.
  #
  # If the application returns a "X-Cascade" pass response, this middleware
  # will send an empty response as result with the correct status code.
  # If any exception happens inside the exceptions app, this middleware
  # catches the exceptions and returns a FAILSAFE_RESPONSE.
  class ShowExceptions
    FAILSAFE_RESPONSE = [500, { 'Content-Type' => 'text/plain' },
      ["500 Internal Server Error\n" \
       "If you are the administrator of this website, then please read this web " \
       "application's log file and/or the web server's log file to find out what " \
       "went wrong."]]

    def initialize(app, exceptions_app)
      @app = app
      @exceptions_app = exceptions_app
    end

    def call(req, res)
      @app.call(req, res)
    rescue Exception => exception
      if req.get_header('action_dispatch.show_exceptions') == false
        raise exception
      else
        render_exception(req, res, exception)
      end
    end

    private

    def render_exception(req, res, exception)
      wrapper = ExceptionWrapper.new(req, exception)
      status  = wrapper.status_code
      req.set_header("action_dispatch.exception", wrapper.exception)
      req.set_header("action_dispatch.original_path", req.path_info)
      req.path_info = "/#{status}"
      response = @exceptions_app.call(req, res)
      response[1]['X-Cascade'] == 'pass' ? pass_response(status) : response
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      FAILSAFE_RESPONSE
    end

    def pass_response(status)
      [status, {"Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0"}, []]
    end
  end
end
