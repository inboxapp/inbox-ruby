require 'nylas/restful_model'
require 'nylas/file'
require 'nylas/mixins'

module Nylas
  class Message < RestfulModel

    parameter :subject
    parameter :snippet
    parameter :from
    parameter :to
    parameter :reply_to
    parameter :cc
    parameter :bcc
    parameter :date
    parameter :thread_id
    parameter :body
    parameter :unread
    parameter :starred
    parameter :folder
    parameter :labels

    include Nylas::ReadUnreadMethods

    def inflate(json)
      super
      @to ||= []
      @cc ||= []
      @bcc ||= []
      @labels ||= []
      self.folder ||= nil

      # This is a special case --- we receive label data from the API
      # as JSON but we want it to behave like an API object.
      @labels.map! do |label_json|
       label = Label.new(@_api)
       label.inflate(label_json)
       label
      end

      if not folder.nil? and folder.is_a?(Hash)
       folder = Folder.new(@_api)
       folder.inflate(@folder)
       @folder = folder
      end
    end


    # Convenience method to access a Ruby Date version of the `date` parameter
    # Will replace the string version of`#date` when we move to 4.0
    def parsed_date
      if date.kind_of?(Numeric)
        Time.at(date).to_datetime
      else
        DateTime.parse(date)
      end
    end

    alias_method :orig_date=, :date=
    # Ensures when we are setting the date on this instance
    # that we are storing it to a unix timestamp.
    def date=date
      if date.respond_to?(:strftime)
        self.orig_date = date.strftime("%s").to_i
      elsif date.kind_of?(String)
        self.orig_date = DateTime.parse(date).strftime("%s").to_i
      else
        self.orig_date = date
      end
    end

    def as_json(options = {})
      hash = {}

      # unread, starred and labels/folder are the only attribute
      # you can modify.
      if not @unread.nil?
        hash["unread"] = @unread
      end

      if not @starred.nil?
        hash["starred"] = @starred
      end

      if not @labels.nil? and @labels != []
        hash["label_ids"] = @labels.map do |label|
          if !label.respond_to?(:id)
            raise TypeError, "label #{label} does not respond to #id"
          end
          label.id
        end
      end

      if !folder.nil? && !folder.respond_to?(:id)
        raise TypeError, "folder #{folder} does not respond to #id"
      end

      if !folder.nil? && folder.respond_to?(:id)
        hash["folder_id"] = folder.id
      end

      hash
    end

    def files
      @files ||= RestfulModelCollection.new(File, @_api, {:message_id=>@id})
    end

    def files?
      !@raw_json['files'].empty?
    end

    def raw
      collection = RestfulModelCollection.new(Message, @_api, message_id: @id)
      url = "#{collection.url}/#{id}/"
      @_api.get(url, accept: 'message/rfc822') do |response, _request, result|
        Nylas.interpret_response(result, response, raw_response: true)
      end
    end

    def expanded
      @_api.get(url('?view=expanded')) do |response, _request, result|
        json = Nylas.interpret_response(result, response, expected_class: Object)
        expanded_message = Nylas::ExpandedMessage.new(@_api)
        expanded_message.inflate(json)
        expanded_message
      end
    end
  end
end
