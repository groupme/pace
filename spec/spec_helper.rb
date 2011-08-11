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
    # We explicitly want to test the Info shutdown hook.
    Pace::Worker.clear_hooks

    Pace.stub(:logger).and_return(Logger.new("/dev/null"))
    Resque.dequeue(Work)
    Resque.dequeue(Play)
  end
end
