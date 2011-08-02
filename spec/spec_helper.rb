require "rubygems"
require "bundler"
Bundler.require :default, :development

class Work
  def self.queue
    "work"
  end
end

class Play
  def self.queue
    "play"
  end
end

RSpec.configure do |config|
  config.before(:each) do
    # Shutdowns unbind Pace::Info's memoized Redis instance, and subsequent
    # uses fail silently (fun!). Maybe move this to an instance.
    Pace::Info.class_eval { @redis = nil }

    # We explicitly want to test the Info shutdown hook.
    Pace::Worker.clear_hooks
    Pace::Info.add_shutdown_hook

    Pace.stub(:logger).and_return(Logger.new("/dev/null"))
    Resque.dequeue(Work)
    Resque.dequeue(Play)
  end
end
