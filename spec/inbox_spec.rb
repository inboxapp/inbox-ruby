require 'uri'
require 'rack'

describe 'Inbox' do
  before (:each) do
    @app_id = 'ABC'
    @app_secret = '123'
    @access_token = 'UXXMOCJW-BKSLPCFI-UQAQFWLO'
  end

  describe "initialize" do
    it "should add the 'before_execution_proc' to the RestClient to set the header" do
      if ::RestClient.before_execution_procs.empty?
        @inbox = Inbox::API.new(@app_id, @app_secret)
        expect(::RestClient.before_execution_procs.empty?).to eq(false)
      end
    end

    it "should not do this multiple times if multiple copies of the Inbox::API are initialized" do
      @inbox = Inbox::API.new(@app_id, @app_secret)
      @inbox = Inbox::API.new(@app_id, @app_secret)
      expect(::RestClient.before_execution_procs.count).to eq(1)
    end
  end

  describe "#url_for_path" do
    before (:each) do
      @inbox = Inbox::API.new(@app_id, @app_secret, @access_token)
    end

    it "should return the url for a provided path" do
      expect(@inbox.url_for_path('/wobble')).to eq("https://#{@inbox.access_token}:@api.nylas.com/wobble")
    end

    it "should return an error if you have not provided an auth token" do
      @inbox = Inbox::API.new(@app_id, @app_secret)
      expect {
        @inbox.url_for_path('/wobble')
      }.to raise_error(Inbox::NoAuthToken)
    end
  end

  describe "#url_for_authentication" do
    before (:each) do
      @inbox = Inbox::API.new(@app_id, @app_secret, @access_token)
    end

    it "should return the OAuth authorize endpoint with the provided redirect_uri" do
      redirect_uri = 'http://redirect.uri'
      url = @inbox.url_for_authentication(redirect_uri)
      params = Rack::Utils.parse_query URI(url).query

      expect(params["client_id"]).to eq(@app_id)
      expect(params["trial"]).to eq('false')
      expect(params["response_type"]).to eq('code')
      expect(params["scope"]).to eq('email')
      expect(params["login_hint"]).to eq('')
      expect(params["redirect_uri"]).to eq(redirect_uri)
    end

    it "should include the login_hint if one is provided" do
      redirect_uri = 'http://redirect.uri'
      url = @inbox.url_for_authentication('http://redirect.uri', 'ben@nylas.com')
      params = Rack::Utils.parse_query URI(url).query

      expect(params["client_id"]).to eq(@app_id)
      expect(params["trial"]).to eq('false')
      expect(params["response_type"]).to eq('code')
      expect(params["scope"]).to eq('email')
      expect(params["login_hint"]).to eq('ben@nylas.com')
      expect(params["redirect_uri"]).to eq(redirect_uri)
    end

    it "should use trial=true if the trial flag is passed" do
      redirect_uri = 'http://redirect.uri'
      url = @inbox.url_for_authentication('http://redirect.uri', 'ben@nylas.com', :trial => true)
      params = Rack::Utils.parse_query URI(url).query

      expect(params["client_id"]).to eq(@app_id)
      expect(params["trial"]).to eq('true')
      expect(params["response_type"]).to eq('code')
      expect(params["scope"]).to eq('email')
      expect(params["login_hint"]).to eq('ben@nylas.com')
      expect(params["redirect_uri"]).to eq(redirect_uri)
    end

    it "should pass state if defined" do
      redirect_uri = 'http://redirect.uri'
      url = @inbox.url_for_authentication('http://redirect.uri', 'ben@nylas.com', {:state => 'empire state'})
      params = Rack::Utils.parse_query URI(url).query

      expect(params["client_id"]).to eq(@app_id)
      expect(params["trial"]).to eq('false')
      expect(params["response_type"]).to eq('code')
      expect(params["scope"]).to eq('email')
      expect(params["login_hint"]).to eq('ben@nylas.com')
      expect(params["redirect_uri"]).to eq(redirect_uri)
      expect(params["state"]).to eq('empire state')
    end

  end

  describe "#self.interpret_response" do
    before (:each) do
      @inbox = Inbox::API.new(@app_id, @app_secret, @access_token)
      @result = double('result')
      allow(@result).to receive(:code).and_return(200)
    end

    context "when an expected_class is provided" do
      context "when the server responds with a 200 but unknown, invalid body" do
        it "should raise an UnexpectedResponse" do
          expect {
            Inbox.interpret_response(@result, "I AM NOT JSON", {:expected_class => Array})
          }.to raise_error(Inbox::UnexpectedResponse)
        end
      end

      context "when the server responds with JSON that does not represent an array" do
        it "should raise an UnexpectedResponse" do
          allow(@result).to receive(:code).and_return(500)
          expect {
            Inbox.interpret_response(@result, "{\"_id\":\"5107089add02dcaecc000003\",\"created_at\":\"2013-01-28T23:24:10Z\",\"domain\":\"generic\",\"name\":\"Untitled\",\"password\":null,\"slug\":\"\",\"tracers\":[{\"_id\":\"5109b5e0dd02dc5976000001\",\"created_at\":\"2013-01-31T00:08:00Z\",\"name\":\"Facebook\"},{\"_id\":\"5109b5f5dd02dc4c43000002\",\"created_at\":\"2013-01-31T00:08:21Z\",\"name\":\"Twitter\"}],\"published_pop_url\":\"http://group3.lvh.me\",\"unpopulated_api_tags\":[],\"unpopulated_api_regions\":[],\"label_names\":[]}", {:expected_class => Array})
          }.to raise_error(Inbox::UnexpectedResponse)
        end
      end
    end

    context "when the server responds with a 400" do
      it "should raise InvalidRequest" do
        allow(@result).to receive(:code).and_return(400)
        expect {
          Inbox.interpret_response(@result, '{"type": "invalid_request_error", "message": "Check your syntax, bro!"}')
        }.to raise_error(Inbox::InvalidRequest)
      end
    end

    context "when the server responds with a 402" do
      it "should raise MessageRejected" do
        allow(@result).to receive(:code).and_return(402)
        expect {
          Inbox.interpret_response(@result, '{"type": "api_error", "message": "Sending to all recipients failed"}')
        }.to raise_error(Inbox::MessageRejected)
      end
    end

    context "when the server responds with a 403" do
      it "should raise AccessDenied" do
        allow(@result).to receive(:code).and_return(403)
        expect {
          Inbox.interpret_response(@result, '')
        }.to raise_error(Inbox::AccessDenied)
      end
    end

    context "when the server responds with a 404" do
      it "should raise ResourceNotFound" do
        allow(@result).to receive(:code).and_return(404)
        expect {
          Inbox.interpret_response(@result, '')
        }.to raise_error(Inbox::ResourceNotFound)
      end
    end

    context "when the server responds with a 429" do
      it "should raise SendingQuotaExceeded" do
        allow(@result).to receive(:code).and_return(429)
        expect {
          Inbox.interpret_response(@result, '{"type": "api_error", "message": "Daily sending quota exceeded"}')
        }.to raise_error(Inbox::SendingQuotaExceeded)
      end
    end

    context "when the server responds with a 503" do
      it "should raise ServiceUnavailable" do
        allow(@result).to receive(:code).and_return(503)
        expect {
          Inbox.interpret_response(@result, '{"type": "api_error", "message": "The server unexpectedly closed the connection"}')
        }.to raise_error(Inbox::ServiceUnavailable)
      end
    end

    context "when the server responds with another status code" do
      it "should raise an UnexpectedResponse" do
        allow(@result).to receive(:code).and_return(500)
        expect {
          Inbox.interpret_response(@result, '')
        }.to raise_error(Inbox::UnexpectedResponse)
      end
    end

    describe "#accounts" do
      before (:each) do
        stub_request(:get, "https://api.nylas.com/a/ABC/accounts?limit=100&offset=0").
         with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'Authorization'=>'Basic MTIzOg==', 'User-Agent'=>'Nylas Ruby SDK 2.0.1 - 2.3.1', 'X-Inbox-Api-Wrapper'=>'ruby'}).
          to_return(
          :status => 200,
          :body => File.read('spec/fixtures/accounts_endpoint.txt'),
          :headers => {"Content-Type" => "application/json"})
        @inbox = Inbox::API.new(@app_id, @app_secret)
      end

      it "should auth with the app_secret" do
        expect(@inbox.accounts).to_not be_nil
      end

      it "should return a list of account objects" do
        expect(@inbox.accounts.first).to be_an Inbox::Account
      end

      it "should return an object corresponding to the mocked values" do
        account = @inbox.accounts.first
        expect(account.trial).to be true
        expect(account.sync_state).to eq('running')
      end

    end
  end

end
