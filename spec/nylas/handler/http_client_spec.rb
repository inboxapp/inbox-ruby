# frozen_string_literal: true

require "webmock/rspec"

class TestHttpClient
  include Nylas::HttpClient
end

describe Nylas::HttpClient do
  subject(:http_client) do
    http_client = TestHttpClient.new
    allow(http_client).to receive(:api_uri).and_return("https://test.api.nylas.com")

    http_client
  end

  describe "#default_headers" do
    before do
      stub_const("Nylas::VERSION", "1.0.0")
      stub_const("RUBY_VERSION", "5.0.0")
    end

    it "returns the default headers" do
      expect(http_client.send(:default_headers)).to eq(
        "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
        "X-Nylas-API-Wrapper" => "ruby"
      )
    end
  end

  describe "#parse_response" do
    it "returns the response if it's already enumerable" do
      response = { "foo" => "bar" }

      expect(http_client.send(:parse_response, response)).to eq(response)
    end

    it "parses the response if it's not enumerable" do
      response = '{"foo":"bar"}'

      expect(http_client.send(:parse_response, response)).to eq(foo: "bar")
    end

    it "raises an error if the response is not valid JSON" do
      response = "foo"

      expect { http_client.send(:parse_response, response) }.to raise_error(Nylas::JsonParseError)
    end
  end

  describe "#build_request" do
    before do
      stub_const("Nylas::VERSION", "1.0.0")
      stub_const("RUBY_VERSION", "5.0.0")
    end

    it "returns the correct request with default values" do
      request = http_client.send(:build_request, method: :get, path: "https://test.api.nylas.com/foo",
                                                 api_key: "fake-key")

      expect(request[:method]).to eq(:get)
      expect(request[:url]).to eq("https://test.api.nylas.com/foo")
      expect(request[:payload]).to be_nil
      expect(request[:headers]).to eq(
        "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
        "X-Nylas-API-Wrapper" => "ruby",
        "Authorization" => "Bearer fake-key"
      )
    end

    it "returns the correct request with custom headers" do
      extra_headers = {
        "X-Custom-Header" => "custom-value",
        "X-Custom-Header-2" => "custom-value-2"
      }
      request = http_client.send(:build_request, method: :get, path: "https://test.api.nylas.com/foo",
                                                 headers: extra_headers, api_key: "fake-key")

      expect(request[:method]).to eq(:get)
      expect(request[:url]).to eq("https://test.api.nylas.com/foo")
      expect(request[:payload]).to be_nil
      expect(request[:headers]).to eq(
        "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
        "X-Nylas-API-Wrapper" => "ruby",
        "Authorization" => "Bearer fake-key",
        "X-Custom-Header" => "custom-value",
        "X-Custom-Header-2" => "custom-value-2"
      )
    end

    it "returns the correct request with custom timeout" do
      request = http_client.send(:build_request, method: :get, path: "https://test.api.nylas.com/foo",
                                                 api_key: "fake-key", timeout: 30)

      expect(request[:method]).to eq(:get)
      expect(request[:url]).to eq("https://test.api.nylas.com/foo")
      expect(request[:payload]).to be_nil
      expect(request[:headers]).to eq(
        "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
        "X-Nylas-API-Wrapper" => "ruby",
        "Authorization" => "Bearer fake-key"
      )
      expect(request[:timeout]).to eq(30)
    end

    it "returns the correct request with query params" do
      query = { query: "bar" }
      request = http_client.send(:build_request, method: :get, path: "https://test.api.nylas.com/foo",
                                                 query: query, api_key: "fake-key")

      expect(request[:method]).to eq(:get)
      expect(request[:url]).to eq("https://test.api.nylas.com/foo?query=bar")
      expect(request[:payload]).to be_nil
      expect(request[:headers]).to eq(
        "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
        "X-Nylas-API-Wrapper" => "ruby",
        "Authorization" => "Bearer fake-key"
      )
    end

    context "when building request with a payload" do
      it "returns the correct request with a json payload" do
        payload = { foo: "bar" }
        request = http_client.send(:build_request, method: :post, path: "https://test.api.nylas.com/foo",
                                                   payload: payload, api_key: "fake-key")

        expect(request[:method]).to eq(:post)
        expect(request[:url]).to eq("https://test.api.nylas.com/foo")
        expect(request[:payload]).to eq('{"foo":"bar"}')
        expect(request[:headers]).to eq(
          "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
          "X-Nylas-API-Wrapper" => "ruby",
          "Authorization" => "Bearer fake-key",
          "Content-type" => "application/json"
        )
      end

      it "returns the correct request with a multipart flag" do
        payload = { "multipart" => true }
        request = http_client.send(:build_request, method: :post, path: "https://test.api.nylas.com/foo",
                                                   payload: payload, api_key: "fake-key")

        expect(request[:method]).to eq(:post)
        expect(request[:url]).to eq("https://test.api.nylas.com/foo")
        expect(request[:payload]).to eq({})
        expect(request[:headers]).to eq(
          "User-Agent" => "Nylas Ruby SDK 1.0.0 - 5.0.0",
          "X-Nylas-API-Wrapper" => "ruby",
          "Authorization" => "Bearer fake-key"
        )
      end
    end
  end

  describe "#execute" do
    let(:mock_request) { instance_double("request", redirection_history: nil) }

    it "returns the response" do
      response_json = {
        foo: "bar"
      }
      request_params = { method: :get, path: "https://test.api.nylas.com/foo", timeout: 30 }
      mock_http_res = instance_double("response", to_hash: {}, code: 200,
                                                  headers: { content_type: "application/json" })
      mock_response = RestClient::Response.create(response_json.to_json, mock_http_res, mock_request)
      mock_response.headers[:content_type] = "application/json"
      allow(RestClient::Request).to receive(:execute).and_yield(mock_response, mock_request, mock_http_res)

      response = http_client.send(:execute, **request_params)

      expect(response).to eq(response_json)
    end

    it "raises a timeout error" do
      request_params = { method: :get, path: "https://test.api.nylas.com/foo", timeout: 30 }
      allow(RestClient::Request).to receive(:execute).and_raise(RestClient::Exceptions::OpenTimeout)

      expect do
        http_client.send(:execute, **request_params)
      end.to raise_error(Nylas::NylasSdkTimeoutError)
    end
  end

  describe "#build_query" do
    it "returns the correct query params" do
      uri = URI.parse("https://test.api.nylas.com/foo")
      params = {
        foo: "bar",
        list: %w[a b c],
        map: { key1: "value1", key2: "value2" }
      }

      final_uri = http_client.send(:build_query, uri, params)

      expect(final_uri.to_s).to eq("https://test.api.nylas.com/foo?foo=bar&list=a&list=b&list=c&map=key1%3Avalue1&map=key2%3Avalue2")
    end
  end

  describe "#build_url" do
    it "returns the correct URL" do
      uri = "https://test.api.nylas.com/foo"
      params = {
        foo: "bar",
        list: %w[a b c],
        map: { key1: "value1", key2: "value2" }
      }
      final_uri = http_client.send(:build_url, uri, params)

      expect(final_uri.to_s).to eq("https://test.api.nylas.com/foo?foo=bar&list=a&list=b&list=c&map=key1%3Avalue1&map=key2%3Avalue2")
    end
  end

  describe "#throw_error" do
    it "raises the correct error" do
      response = {
        request_id: "request-id",
        error: {
          type: "api_error",
          message: "An unexpected error occurred",
          provider_error: "This is the provider error"
        }
      }

      err_obj = http_client.send(:throw_error, response, 400)

      expect(err_obj).to be_a(Nylas::NylasApiError)
      expect(err_obj.message).to eq("An unexpected error occurred")
      expect(err_obj.request_id).to eq("request-id")
      expect(err_obj.provider_error).to eq("This is the provider error")
      expect(err_obj.type).to eq("api_error")
    end
  end

  describe "#error_hash_to_exception" do
    it "raises the correct error" do
      response = {
        request_id: "request-id",
        error: {
          type: "api_error",
          message: "An unexpected error occurred",
          provider_error: "This is the provider error"
        }
      }

      err_obj = http_client.send(:error_hash_to_exception, response, 400, "https://test.api.nylas.com/foo")

      expect(err_obj).to be_a(Nylas::NylasApiError)
      expect(err_obj.message).to eq("An unexpected error occurred")
      expect(err_obj.request_id).to eq("request-id")
      expect(err_obj.provider_error).to eq("This is the provider error")
      expect(err_obj.type).to eq("api_error")
    end

    it "raises NylasApiError if the error response is a string" do
      response = {
        request_id: "request-id",
        error: "Bad Gateway"
      }

      err_obj = http_client.send(:error_hash_to_exception, response, 502, "https://test.api.nylas.com/foo")

      expect(err_obj).to be_a(Nylas::NylasApiError)
      expect(err_obj.message).to eq("Bad Gateway")
      expect(err_obj.request_id).to eq("request-id")
      expect(err_obj.provider_error).to eq(nil)
      expect(err_obj.status_code).to eq(502)
      expect(err_obj.type).to eq("NylasApiError")
    end

    it "raises the correct error for OAuth" do
      response = {
        error: "invalid_request",
        error_description: "The request is missing a required parameter",
        error_uri: "https://tools.ietf.org/html/rfc6749#section-5.2",
        error_code: 400
      }

      err_obj = http_client.send(:error_hash_to_exception, response, 400, "https://test.api.nylas.com/v3/connect/token")

      expect(err_obj).to be_a(Nylas::NylasOAuthError)
      expect(err_obj.message).to eq("The request is missing a required parameter")
      expect(err_obj.error_uri).to eq("https://tools.ietf.org/html/rfc6749#section-5.2")
      expect(err_obj.error_code).to eq(400)
    end
  end

  describe "#handle_failed_response" do
    it "raises the correct error" do
      response = {
        request_id: "request-id",
        error: {
          type: "api_error",
          message: "An unexpected error occurred",
          provider_error: "This is the provider error"
        }
      }

      expect do
        http_client.send(:handle_failed_response, 400, response,
                         "https://test.api.nylas.com/foo")
      end.to raise_error(Nylas::NylasApiError)
    end

    it "raises a NylasApiError for a non-JSON response" do
      response = "foo"

      expect do
        http_client.send(:handle_failed_response, 400, response,
                         "https://test.api.nylas.com/foo")
      end.to raise_error(Nylas::NylasApiError)
    end

    it "does not raise an error for a successful response" do
      response = {
        request_id: "request-id",
        error: {
          type: "api_error",
          message: "An unexpected error occurred",
          provider_error: "This is the provider error"
        }
      }

      expect do
        http_client.send(:handle_failed_response, 200, response,
                         "https://test.api.nylas.com/foo")
      end.not_to raise_error
    end
  end

  describe "#parse_json_evaluate_error" do
    it "returns the parsed response on success" do
      response = {
        request_id: "request-id",
        data: {
          foo: "bar"
        }
      }

      expect(http_client.send(:parse_json_evaluate_error, 200, response.to_json,
                              "https://test.api.nylas.com/foo", "application/json")).to eq(response)
    end

    it "raises a Nylas::JsonParseError if the response is not valid JSON" do
      response = "foo"

      expect do
        http_client.send(:parse_json_evaluate_error, 200, response,
                         "https://test.api.nylas.com/foo", "application/json")
      end.to raise_error(Nylas::JsonParseError)
    end

    it "raises the correct error" do
      response = {
        request_id: "request-id",
        error: {
          type: "api_error",
          message: "An unexpected error occurred",
          provider_error: "This is the provider error"
        }
      }

      expect do
        http_client.send(:parse_json_evaluate_error, 400, response.to_json,
                         "https://test.api.nylas.com/foo", "application/json")
      end.to raise_error(Nylas::NylasApiError)
    end

    it "raises a NylasApiError for a non-JSON response" do
      response = "foo"

      expect do
        http_client.send(:parse_json_evaluate_error, 400, response,
                         "https://test.api.nylas.com/foo")
      end.to raise_error(Nylas::NylasApiError)
    end
  end

  describe "#handle_response" do
    let(:http) { instance_double("Net::HTTP") }
    let(:get_request) { instance_double("Net::HTTP::Get") }
    let(:path) { "https://test.api.nylas.com/foo" }

    it "returns the response body on success" do
      response = instance_double("Net::HTTPSuccess", is_a?: true, body: "response body")
      allow(http).to receive(:request).and_yield(response)

      expect(http_client.send(:handle_response, http, get_request, path)).to eq("response body")
    end

    it "reads the response body if a block is given" do
      response = instance_double("Net::HTTPSuccess", is_a?: true)
      allow(response).to receive(:read_body).and_yield("response body")
      allow(http).to receive(:request).and_yield(response)

      expect do |b|
        http_client.send(:handle_response, http, get_request, path, &b)
      end.to yield_with_args("response body")
    end

    it "raises the correct error" do
      response = instance_double("Net::HTTPSuccess", is_a?: false, code: 400, body: "response body")
      allow(response).to receive(:[]).with("Content-Type").and_return("application/json")
      allow(http).to receive(:request).and_yield(response)

      expect do
        http_client.send(:handle_response, http, get_request, path)
      end.to raise_error(Nylas::NylasApiError)
    end
  end

  describe "#setup_http" do
    it "returns the correct http object" do
      req, uri, http = http_client.send(:setup_http, "https://test.api.nylas.com/foo", 30, { foo: "bar" },
                                        { query: "param" }, "abc-123")

      expect(req[:method]).to eq(:get)
      expect(req[:url]).to eq("https://test.api.nylas.com/foo?query=param")
      expect(req[:payload]).to be_nil
      expect(req[:timeout]).to eq(30)
      expect(req[:headers][:foo]).to eq("bar")
      expect(req[:headers]["Authorization"]).to eq("Bearer abc-123")
      expect(uri).to be_a(URI)
      expect(uri.to_s).to eq("https://test.api.nylas.com/foo?query=param")
      expect(http).to be_a(Net::HTTP)
      expect(http.address).to eq("test.api.nylas.com")
      expect(http.instance_variable_get("@use_ssl")).to be_truthy
      expect(http.read_timeout).to eq(30)
      expect(http.open_timeout).to eq(30)
    end
  end

  describe "#download_request" do
    it "returns the raw response body" do
      response_body = {
        request_id: "id-123",
        data: {
          foo: "bar"
        }
      }
      stub_request(:get, "https://test.api.nylas.com/foo")
        .to_return(status: 200, body: response_body.to_s, headers: { "Content-Type" => "application/json" })
      response = http_client.send(:download_request, path: "https://test.api.nylas.com/foo",
                                                     timeout: 30)

      expect(response).to eq(response_body.to_s)
    end

    it "raises a timeout error" do
      stub_request(:get, "https://test.api.nylas.com/foo")
        .to_timeout

      expect do
        http_client.send(:download_request, path: "https://test.api.nylas.com/foo",
                                            timeout: 30)
      end.to raise_error(Nylas::NylasSdkTimeoutError)
    end
  end
end
