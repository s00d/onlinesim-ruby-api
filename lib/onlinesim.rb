# frozen_string_literal: true

require_relative "onlinesim/version"
require_relative "onlinesim/errors"
require_relative "onlinesim/normalize"
require_relative "onlinesim/transport"
require_relative "onlinesim/numbers"
require_relative "onlinesim/rent"
require_relative "onlinesim/user"
require_relative "onlinesim/free"
require_relative "onlinesim/wait"
require_relative "onlinesim/webhook"
require_relative "onlinesim/client"

# Ruby client for the OnlineSim API. Entry point: OnlineSim::Client.
module OnlineSim
  # Offline fake of the API for tests (lib/onlinesim/mock.rb). Loaded on first use, so it costs nothing otherwise.
  autoload :MockOnlineSim, File.expand_path("onlinesim/mock", __dir__)
end
