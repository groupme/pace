# Notify Hoptoad if an exception occurs
#
# If an exception bubbles up to Pace, notify Hoptoad in a background thread.
# This implementation is mostly stolen from Resque.
#
# Before using this, you need to configure Hoptoad:
#
#     require "pace"
#     require "pace/hoptoad"
#
#     HoptoadNotifier.configure do |config|
#       config.api_key = 'API-KEY'
#     end
#
begin
  # HoptoadNotifier requires active_support anyway,
  # but forgot to load their actual dependencies.
  require 'hoptoad_notifier'
  require "active_support/core_ext"
end

Pace::Worker.add_hook(:error) do |json, error|
  EM.defer do
    HoptoadNotifier.notify_or_ignore(error,
      :parameters => {:json => json},
      :environment_name => (ENV["RACK_ENV"] || ENV["RAILS_ENV"])
    )
  end
end
