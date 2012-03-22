require 'spec_helper'

describe Pace::Queue do
  class CallbackJob
    def self.queue
      "callback"
    end
  end

  describe ".new" do
    it "takes a redis URL and returns an instance of Pace::Queue" do
      redis_url = "redis://localhost:6379/0"
      EM::Hiredis.should_receive(:connect).with(redis_url)
      Pace::Queue.new(redis_url)
    end
  end

  describe "#enqueue" do
    it "adds a new Resque-compatible job to the specified queue" do
      EM.run {
        queue = Pace::Queue.new("redis://localhost:6379/0")
        queue.enqueue(CallbackJob.queue, CallbackJob, "some" => "data") { EM.stop }
      }

      Resque.pop(CallbackJob.queue).should == {
        "class" => "CallbackJob",
        "args"  => [{"some" => "data"}]
      }
    end
  end
end
