module Nylas
  # Plain HTTP client that can be used to interact with the Nylas API sans any type casting.
  class HttpClient
    include Logging
    attr_accessor :api_server
    attr_reader :access_token
    attr_reader :app_id
    attr_reader :app_secret

    # @param app_id [String] Your application id from the Nylas Dashboard
    # @param app_secret [String] Your application secret from the Nylas Dashboard
    # @param access_token [String] (Optional) Your users access token.
    # @param api_server [String] (Optional) Which Nylas API Server to connect to. Only change this if
    #                            you're using a self-hosted Nylas instance.
    # @param service_domain [String] (Optional) Host you are authenticating OAuth against.
    # @return [Nylas::API]
    def initialize(app_id: , app_secret:, access_token: nil, api_server: 'https://api.nylas.com',
                   service_domain: 'api.nylas.com')
      unless api_server.include?('://')
        raise "When overriding the Nylas API server address, you must include https://"
      end
      @api_server = api_server
      @access_token = access_token
      @app_secret = app_secret
      @app_id = app_id
      @service_domain = service_domain
      @default_headers = {
        'X-Nylas-API-Wrapper' => 'ruby',
        'User-Agent' => "Nylas Ruby SDK #{Nylas::VERSION} - #{RUBY_VERSION}",
        'Content-types' => 'application/json'
      }
    end

    # Sends a request to the Nylas API and rai
    # @param method [Symbol] HTTP method for the API call. Either :get, :post, :delete, or :patch
    # @param url [String] (Optional, defaults to nil) - Full URL to access. Deprecated and will be removed in
    #                     5.0.
    # @param path [String] (Optional, defaults to nil) - Relative path from the API Base. Preferred way to
    #                      execute arbitrary or-not-yet-SDK-ified API commands.
    # @param headers [Hash] (Optional, defaults to {}) - Additional HTTP headers to include in the payload.
    # @param query [Hash] (Optional, defaults to {}) - Hash of names and values to include in the query
    #                      section of the URI fragment
    # @param payload [String,Hash] (Optional, defaults to nil) - Body to send with the request.
    # @return [Array Hash Stringn]
    def execute(method: , url: nil, path: nil, headers: {}, query: {}, payload: nil)
      headers[:params] = query
      url = url || url_for_path(path)
      resulting_headers = @default_headers.merge(headers)
      rest_client_execute(method: method, url: url, payload: payload,
                          headers: resulting_headers) do |response, request, result|

        response = parse_response(response)
        handle_failed_response(result: result, response: response)
        response
      end
    end
    inform_on :execute, level: :debug,
      also_log: { result: true, values: [:method, :url, :path, :headers, :query, :payload] }

    # Syntactical sugar for making GET requests via the API.
    # @see #execute
    def get(path: nil, url: nil, headers: {}, query: {})
      execute(method: :get, path: path, query: query, url: url, headers: headers)
    end

    # Syntactical sugar for making POST requests via the API.
    # @see #execute
    def post(path: nil, url: nil, payload: nil, headers: {}, query: {})
      execute(method: :post, path: path, url: url, headers: headers, query: query, payload: payload)
    end

    # Syntactical sugar for making PUT requests via the API.
    # @see #execute
    def put(path: nil, url: nil, payload: ,headers: {}, query: {})
      execute(method: :put, path: path, url: url, headers: headers, query: query, payload: payload)
    end

    # Syntactical sugar for making DELETE requests via the API.
    # @see #execute
    def delete(path: nil, url: nil, payload: nil, headers: {}, query: {})
      execute(method: :delete, path: path, url: url, headers: headers, query: query, payload: payload)
    end



    private def rest_client_execute(method: , url: , headers: , payload: , &block)
      ::RestClient::Request.execute(method: method, url: url, payload: payload,
                                    headers: headers, &block)
    end
    inform_on :rest_client_execute, level: :debug,
      also_log: { result: true, values: [:method, :url, :headers, :payload] }

    private def parse_response(response)
      begin
        response.kind_of?(Enumerable) ? response : JSON.parse(response, symbolize_names: true)
      rescue JSON::ParserError
        response
      end
    end

    private def url_for_path(path)
      raise NoAuthToken.new if @access_token == nil and (@app_secret != nil or @app_id != nil)
      protocol, domain = @api_server.split('//')
      "#{protocol}//#{@access_token}:@#{domain}#{path}"
    end

    private def handle_failed_response(result:, response:)
      http_code = result.code.to_i

      handle_anticipated_failure_mode(http_code: http_code, response: response)
      raise UnexpectedResponse.new(result.msg) if result.is_a?(Net::HTTPClientError)
    end

    private def handle_anticipated_failure_mode(http_code:, response:)
      if http_code != 200
        exception = HTTP_CODE_TO_EXCEPTIONS.fetch(http_code, APIError)
        if response.is_a?(Hash)
          raise exception.new(response['type'], response['message'], response.fetch('server_error', nil))
        end
      end
    end
  end
end
