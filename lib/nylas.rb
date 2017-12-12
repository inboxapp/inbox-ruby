require "json"
require "rest-client"

require "ostruct"
require "forwardable"

require_relative "nylas/version"
require_relative "nylas/errors"

require_relative "nylas/logging"
require_relative "nylas/registry"
require_relative "nylas/types"
require_relative "nylas/constraints"

require_relative "nylas/collection"
require_relative "nylas/model"

# Attribute types supported by the API
require_relative "nylas/email_address"
require_relative "nylas/im_address"
require_relative "nylas/physical_address"
require_relative "nylas/phone_number"
require_relative "nylas/web_page"
require_relative "nylas/nylas_date"

# Models supported by the API
require_relative "nylas/account"
require_relative "nylas/contact"
require_relative "nylas/current_account"

require_relative "nylas/http_client"
require_relative "nylas/api"

# an SDK for interacting with the Nylas API
# @see https://docs.nylas.com/reference
module Nylas
  Types.registry[:email_address] = EmailAddressType.new
  Types.registry[:im_address] = IMAddressType.new
  Types.registry[:physical_address] = PhysicalAddressType.new
  Types.registry[:phone_number] = PhoneNumberType.new
  Types.registry[:web_page] = WebPageType.new
  Types.registry[:nylas_date] = NylasDateType.new
end
