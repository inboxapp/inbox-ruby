# frozen_string_literal: true

require "rest-client"

require_relative "../errors"
require_relative "../version"

# Module for working with HTTP Client
module Nylas
  require "yajl"
  require "base64"

  # Plain HTTP client that can be used to interact with the Nylas API without any type casting.
  module HttpClient
    protected

    attr_accessor :api_server
    attr_writer :default_headers

    # Sends a request to the Nylas API. Returns a successful response if the request succeeds, or a
    # failed response if the request encounters a JSON parse error.
    #
    # @param method [Symbol] HTTP method for the API call. Either :get, :post, :delete, or :patch.
    # @param path [String, nil] Relative path from the API Base. This is the preferred way to execute
    # arbitrary or-not-yet-SDK-ified API commands.
    # @param timeout [Integer, nil] Timeout value to send with the request.
    # @param headers [Hash, {}] Additional HTTP headers to include in the payload.
    # @param query [Hash, {}] Hash of names and values to include in the query section of the URI
    # fragment.
    # @param payload [Hash, nil] Body to send with the request.
    # @param api_key [Hash, nil] API key to send with the request.
    # @return [Object] Parsed JSON response from the API.
    def execute(method:, path:, timeout:, headers: {}, query: {}, payload: nil, api_key: nil)
      request = build_request(method: method, path: path, headers: headers,
                              query: query, payload: payload, api_key: api_key, timeout: timeout)
      begin
        rest_client_execute(**request) do |response, _request, result|
          content_type = nil
          if response.headers && response.headers[:content_type]
            content_type = response.headers[:content_type].downcase
          end

          parse_json_evaluate_error(result.code.to_i, response, path, content_type)
        end
      rescue RestClient::Exceptions::OpenTimeout, RestClient::Exceptions::ReadTimeout
        raise Nylas::NylasSdkTimeoutError.new(request[:path], timeout)
      end
    end

    # Sends a request to the Nylas API, specifically for downloading data.
    # This method supports streaming the response by passing a block, which will be executed
    # with each chunk of the response body as it is read. If no block is provided, the entire
    # response body is returned.
    #
    # @param path [String] Relative path from the API Base. This is the preferred way to execute
    # arbitrary or-not-yet-SDK-ified API commands.
    # @param timeout [Integer] Timeout value to send with the request.
    # @param headers [Hash, {}] Additional HTTP headers to include in the payload.
    # @param query [Hash, {}] Hash of names and values to include in the query section of the URI
    # fragment.
    # @param api_key [Hash, nil] API key to send with the request.
    # @yieldparam chunk [String] A chunk of the response body.
    # @return [nil, String] Returns nil when a block is given (streaming mode).
    #     When no block is provided, the return is the entire raw response body.
    def download_request(path:, timeout:, headers: {}, query: {}, api_key: nil, &block)
      request, uri, http = setup_http(path, timeout, headers, query, api_key)

      begin
        http.start do |setup_http|
          get_request = Net::HTTP::Get.new(uri)
          request[:headers].each { |key, value| get_request[key] = value }

          handle_response(setup_http, get_request, path, &block)
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Nylas::NylasSdkTimeoutError.new(request[:url], timeout)
      end
    end

    # Builds a request sent to the Nylas API.
    #
    # @param method [Symbol] HTTP method for the API call. Either :get, :post, :delete, or :patch.
    # @param path [String, nil] Relative path from the API Base.
    # @param headers [Hash, {}] Additional HTTP headers to include in the payload.
    # @param query [Hash, {}] Hash of names and values to include in the query section of the URI
    # fragment.
    # @param payload [Hash, nil] Body to send with the request.
    # @param timeout [Integer, nil] Timeout value to send with the request.
    # @param api_key [Hash, nil] API key to send with the request.
    # @return [Object] The request information after processing. This includes an updated payload
    # and headers.
    def build_request(
      method:, path: nil, headers: {}, query: {}, payload: nil, timeout: nil, api_key: nil
    )
      url = build_url(path, query)
      resulting_headers = default_headers.merge(headers).merge(auth_header(api_key))
      if !payload.nil? && !payload["multipart"]
        payload = payload&.to_json
        resulting_headers["Content-type"] = "application/json"
      elsif !payload.nil? && payload["multipart"]
        payload.delete("multipart")
      end

      { method: method, url: url, payload: payload, headers: resulting_headers, timeout: timeout }
    end

    # Sets the default headers for API requests.
    def default_headers
      @default_headers ||= {
        "X-Nylas-API-Wrapper" => "ruby",
        "User-Agent" => "Nylas Ruby SDK #{Nylas::VERSION} - #{RUBY_VERSION}"
      }
    end

    # Parses the response from the Nylas API.
    def parse_response(response)
      return response if response.is_a?(Enumerable)

      Yajl::Parser.new(symbolize_names: true).parse(response)
    rescue Yajl::ParseError
      raise Nylas::JsonParseError
    end

    private

    # Sends a request to the Nylas REST API.
    #
    # @param method [Symbol] HTTP method for the API call. Either :get, :post, :delete, or :patch.
    # @param url [String] URL for the API call.
    # @param headers [Hash] HTTP headers to include in the payload.
    # @param payload [String, Hash] Body to send with the request.
    # @param timeout [Hash] Timeout value to send with the request.
    def rest_client_execute(method:, url:, headers:, payload:, timeout:, &block)
      ::RestClient::Request.execute(method: method, url: url, payload: payload,
                                    headers: headers, timeout: timeout, &block)
    end

    def setup_http(path, timeout, headers, query, api_key)
      request = build_request(method: :get, path: path, headers: headers,
                              query: query, api_key: api_key, timeout: timeout)
      uri = URI(request[:url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = timeout
      http.open_timeout = timeout
      [request, uri, http]
    end

    def handle_response(http, get_request, path, &block)
      http.request(get_request) do |response|
        if response.is_a?(Net::HTTPSuccess)
          return response.body unless block_given?

          response.read_body(&block)
        else
          parse_json_evaluate_error(response.code.to_i, response.body, path, response["Content-Type"])
          break
        end
      end
    end

    # Parses the response from the Nylas API and evaluates for errors.
    def parse_json_evaluate_error(http_code, response, path, content_type = nil)
      begin
        response = parse_response(response) if content_type == "application/json"
      rescue Nylas::JsonParseError
        handle_failed_response(http_code, response, path)
        raise
      end

      handle_failed_response(http_code, response, path)
      response
    end

    # Handles failed responses from the Nylas API.
    def handle_failed_response(http_code, response, path)
      return if HTTP_SUCCESS_CODES.include?(http_code)

      case response
      when Hash
        raise error_hash_to_exception(response, http_code, path)
      else
        raise NylasApiError.parse_error_response(response, http_code)
      end
    end

    # Converts error hashes to exceptions.
    def error_hash_to_exception(response, status_code, path)
      return if !response || !response.key?(:error)

      if %W[#{api_uri}/v3/connect/token #{api_uri}/v3/connect/revoke].include?(path)
        NylasOAuthError.new(response[:error], response[:error_description], response[:error_uri],
                            response[:error_code], status_code)
      else
        throw_error(response, status_code)
      end
    end

    def throw_error(response, status_code)
      error_obj = response[:error]

      # If `error_obj` is just a string, turn it into a hash with default keys.
      if error_obj.is_a?(String)
        error_obj = {
          type: "NylasApiError",
          message: error_obj
        }
      end

      provider_error = error_obj.fetch(:provider_error, nil) if error_obj.is_a?(Hash)

      NylasApiError.new(
        error_obj[:type],
        error_obj[:message],
        status_code,
        provider_error,
        response[:request_id]
      )
    end

    # Adds query parameters to a URL.
    # @param url [String] The base URL.
    # @param query [Hash] The query parameters to add to the URL.
    # @return [String] Processed URL, including query params.
    def build_url(url, query = nil)
      unless query.nil? || query.empty?
        uri = URI.parse(url)
        uri = build_query(uri, query)
        url = uri.to_s
      end

      url
    end

    # Build the query string for a URI.
    # @param uri [URI] URL to add the query to.
    # @param query [Hash] The query params to include in the query.
    # @return [URI] The URI object with the query parameters included.
    def build_query(uri, query)
      query.each do |key, value|
        case value
        when Array
          value.each do |item|
            qs = "#{URI.encode_www_form_component(key)}=#{URI.encode_www_form_component(item)}"
            uri.query = [uri.query, qs].compact.join("&")
          end
        when Hash
          value.each do |k, v|
            qs = "#{URI.encode_www_form_component(key)}=#{URI.encode_www_form_component("#{k}:#{v}")}"
            uri.query = [uri.query, qs].compact.join("&")
          end
        else
          qs = "#{URI.encode_www_form_component(key)}=#{URI.encode_www_form_component(value)}"
          uri.query = [uri.query, qs].compact.join("&")
        end
      end

      uri
    end

    # Set the authorization header for an API query.
    def auth_header(api_key)
      { "Authorization" => "Bearer #{api_key}" }
    end
  end
end
