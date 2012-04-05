# Notify Airbrake if an exception occurs
#
# This provides a proc that can be used as an error hook.
# Before using this, you need to configure Airbrake.
#
#     require "pace"
#     require "pace/airbrake"
#
#     Airbrake.configure do |config|
#       config.api_key = 'API-KEY'
#     end
#
#     worker = Pace::Worker.new(QUEUE)
#     worker.add_hook(:error, Pace::Airbrake.hook)
#
require "airbrake"

module Pace
  module Airbrake
    def self.hook
      Proc.new do |json, error|
        EM.defer do
          notification = {
            :error_class      => error.class.name,
            :error_message    => "#{error.class.name}: #{error.message}",
            :backtrace        => error.backtrace,
            :parameters       => {},
            :environment_name => (ENV["RACK_ENV"] || ENV["RAILS_ENV"])
          }
          notification[:parameters][:json] = json if json

          ::Airbrake.notify(notification)
        end
      end
    end
  end
end
