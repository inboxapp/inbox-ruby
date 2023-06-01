# frozen_string_literal: true

require "json"
require "rest-client"

# BUGFIX
#   See https://github.com/sparklemotion/http-cookie/issues/27
#   and https://github.com/sparklemotion/http-cookie/issues/6
#
# CookieJar uses unsafe class caching for dynamically loading cookie jars
# If 2 rest-client instances are instantiated at the same time, (in threads)
# non-deterministic behaviour can occur whereby the Hash cookie jar isn't
# properly loaded and cached.
# Forcing an instantiation of the jar onload will force the CookieJar to load
# before the system has a chance to spawn any threads.
# Note this should technically be fixed in rest-client itself however that
# library appears to be stagnant so we're forced to fix it here
# This object should get GC'd as it's not referenced by anything
HTTP::CookieJar.new

require "ostruct"
require "forwardable"

require_relative "nylas/version"
require_relative "nylas/errors"
require_relative "nylas/client"
require_relative "nylas/config"

require_relative "nylas/handler/http_client"

require_relative "nylas/resources/application"
require_relative "nylas/resources/auth"
require_relative "nylas/resources/calendars"
require_relative "nylas/resources/events"
require_relative "nylas/resources/grants"
require_relative "nylas/resources/providers"
require_relative "nylas/resources/redirect_uris"
require_relative "nylas/resources/scopes"
require_relative "nylas/resources/webhooks"
