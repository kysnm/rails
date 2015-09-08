require 'rack/utils'
require 'active_support/core_ext/uri'

module ActionDispatch
  # This middleware returns a file's contents from disk in the body response.
  # When initialized, it can accept an optional 'Cache-Control' header, which
  # will be set when a response containing a file's contents is delivered.
  #
  # This middleware will render the file specified in `env["PATH_INFO"]`
  # where the base path is in the +root+ directory. For example, if the +root+
  # is set to `public/`, then a request with `env["PATH_INFO"]` of
  # `assets/application.js` will return a response with the contents of a file
  # located at `public/assets/application.js` if the file exists. If the file
  # does not exist, a 404 "File not Found" response will be returned.
  class FileHandler
    def initialize(root, cache_control, index: 'index')
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(root)}/
      headers        = cache_control && { 'Cache-Control' => cache_control }
      @file_server = ::Rack::File.new(@root, headers)
      @index = index
    end

    # Takes a path to a file. If the file is found, has valid encoding, and has
    # correct read permissions, the return value is a URI-escaped string
    # representing the filename. Otherwise, false is returned.
    #
    # Used by the `Static` class to check the existence of a valid file
    # in the server's `public/` directory (see Static#call).
    def match?(path)
      path = ::Rack::Utils.unescape_path path
      return false unless path.valid_encoding?
      path = Rack::Utils.clean_path_info path

      paths = [path, "#{path}#{ext}", "#{path}/#{@index}#{ext}"]

      if match = paths.detect { |p|
        path = File.join(@root, p.force_encoding('UTF-8'.freeze))
        begin
          File.file?(path) && File.readable?(path)
        rescue SystemCallError
          false
        end

      }
        return ::Rack::Utils.escape_path(match)
      end
    end

    def call(req, res)
      serve req, res
    end

    def serve(request, res)
      path      = request.path_info
      gzip_path = gzip_file_path(path)

      res.headers['Vary'] = 'Accept-Encoding' if gzip_path

      if gzip_path && gzip_encoding_accepted?(request)
        request.path_info           = gzip_path
        @file_server.call(request, res)
        if status == 304
          return [status, headers, body]
        end
        headers['Content-Encoding'] = 'gzip'
        headers['Content-Type']     = content_type(path)
      else
        @file_server.call(request, res)
      end
    ensure
      request.path_info = path
    end

    private
      def ext
        ::ActionController::Base.default_static_extension
      end

      def content_type(path)
        ::Rack::Mime.mime_type(::File.extname(path), 'text/plain'.freeze)
      end

      def gzip_encoding_accepted?(request)
        request.accept_encoding =~ /\bgzip\b/i
      end

      def gzip_file_path(path)
        can_gzip_mime = content_type(path) =~ /\A(?:text\/|application\/javascript)/
        gzip_path     = "#{path}.gz"
        if can_gzip_mime && File.exist?(File.join(@root, ::Rack::Utils.unescape_path(gzip_path)))
          gzip_path
        else
          false
        end
      end
  end

  # This middleware will attempt to return the contents of a file's body from
  # disk in the response. If a file is not found on disk, the request will be
  # delegated to the application stack. This middleware is commonly initialized
  # to serve assets from a server's `public/` directory.
  #
  # This middleware verifies the path to ensure that only files
  # living in the root directory can be rendered. A request cannot
  # produce a directory traversal using this middleware. Only 'GET' and 'HEAD'
  # requests will result in a file being returned.
  class Static
    def initialize(app, path, cache_control = nil, index: 'index')
      @app = app
      @file_handler = FileHandler.new(path, cache_control, index: index)
    end

    def call(req, res)
      if req.get? || req.head?
        path = req.path_info.chomp('/'.freeze)
        if match = @file_handler.match?(path)
          req.path_info = match
          return @file_handler.serve(req, res)
        end
      end

      @app.call(req, res)
    end
  end
end
