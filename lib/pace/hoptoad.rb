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
  require 'hoptoad_notifier'
rescue LoadError
  raise "Can't find 'hoptoad_notifier' gem. Please add it to your Gemfile or install it."
end

Pace.on_error do |job, error|
  EM.defer do
    HoptoadNotifier.notify_or_ignore(error,
      :parameters => {:job => job},
      :environment_name => (ENV["RACK_ENV"] || ENV["RAILS_ENV"])
    )
  end
end
