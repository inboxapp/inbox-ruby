require 'restful_model'
require 'account'
require 'tag'
require 'message'
require 'draft'
require 'contact'
require 'file'
require 'calendar'
require 'event'

# Rather than saying require 'thread', we need to explicitly force
# the thread model to load. Otherwise, we can't reference it below.
# Thread still refers to the built-in Thread type, and Inbox::Thread
# is undefined.
load "thread.rb"

module Inbox

  class Namespace < RestfulModel

    parameter :account_id
    parameter :name
    parameter :email_address
    parameter :provider

    def self.collection_name
      "n"
    end

    def threads
      @threads ||= RestfulModelCollection.new(Thread, @_api, @id)
    end

    def tags
      @tags ||= RestfulModelCollection.new(Tag, @_api, @id)
    end

    def messages
      @messages ||= RestfulModelCollection.new(Message, @_api, @id)
    end

    def files
      @files ||= RestfulModelCollection.new(File, @_api, @id)
    end

    def drafts
      @drafts ||= RestfulModelCollection.new(Draft, @_api, @id)
    end

    def contacts
      @contacts ||= RestfulModelCollection.new(Contact, @_api, @id)
    end

    def calendars
      @calendars ||= RestfulModelCollection.new(Calendar, @_api, @id)
    end

    def events
      @events ||= RestfulModelCollection.new(Event, @_api, @id)
    end

    def get_cursor(timestamp)
      # Get the cursor corresponding to a specific timestamp.
      path = @_api.url_for_path("n/#{@namespace_id}/delta/generate_cursor")
      data = { :start => timestamp }

      cursor = nil

      RestClient.post(path, data.to_json, :content_type => :json) do |response,request,result|
        json = Inbox.interpret_response(result, response, {:expected_class => Object})
        cursor = json["cursor"]
      end

      return cursor
    end

    OBJECTS_TABLE = {
      "account" => Inbox::Account,
      "calendar" => Inbox::Calendar,
      "draft" => Inbox::Draft,
      "thread" => Inbox::Thread,
      "account" => Inbox::Account,
      "calendar" => Inbox::Calendar,
      "contact" => Inbox::Contact,
      "draft" => Inbox::Draft,
      "event" => Inbox::Event,
      "file" => Inbox::File,
      "message" => Inbox::Message,
      "namespace" => Inbox::Namespace,
      "tag" => Inbox::Tag,
      "thread" => Inbox::Thread
    }

    def deltas(cursor, exclude_types=[])
      exclude_string = ""

      if not exclude_types.empty?
        exclude_string = "&exclude_types="

        exclude_types.each do |value|
          count = 0
          if OBJECTS_TABLE.has_value?(value)
            param_name = OBJECTS_TABLE.key(value)
            exclude_string += "#{param_name},"
          end
        end
      end

      exclude_string = exclude_string[0..-2]

      # loop and yield deltas until we've come to the end.
      loop do
        path = @_api.url_for_path("n/#{@namespace_id}/delta?cursor=#{cursor}#{exclude_string}")
        json = nil

        RestClient.get(path) do |response,request,result|
          json = Inbox.interpret_response(result, response, {:expected_class => Object})
        end

        start_cursor = json["cursor_start"]
        end_cursor = json["cursor_end"]

        json["deltas"].each do |delta|
          cls = OBJECTS_TABLE[delta['object']]
          obj = cls.new(@_api, @namespace_id)

          case delta["event"]
          when 'create', 'modify'
              obj.inflate(delta['attributes'])
              obj.cursor = delta["cursor"]
              yield delta["event"], obj
          when 'delete'
              obj.id = delta["id"]
              obj.cursor = delta["cursor"]
              yield delta["event"], obj
          end
        end

        break if start_cursor == end_cursor
        cursor = end_cursor
      end
    end

  end
end
