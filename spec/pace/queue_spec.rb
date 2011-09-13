require 'spec_helper'

describe Pace::Queue do
  describe ".enqueue" do
    class CallbackJob
      def self.queue
        "callback"
      end
    end

    it "adds a new, Resque-compatible job into the specified queue" do
      options = {:x => 1, :y => 2}

      Resque.enqueue(Work)

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        Pace::Queue.enqueue(CallbackJob.queue, CallbackJob, options) { EM.stop }
      end

      new_job = Resque.pop(CallbackJob.queue)
      new_job.should == {
        "class" => "CallbackJob",
        "args"  => [{"x" => 1, "y" => 2}]
      }

      # It's identical to a job added w/ Resque (important!)
      Resque.enqueue(CallbackJob, options)
      resque_job = Resque.pop(CallbackJob.queue)
      resque_job.should == new_job
    end
  end
end
