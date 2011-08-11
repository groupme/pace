require 'spec_helper'

describe Pace::Instruments::Redistat do
  before do
    @job = {
      "class" => "FakeJob",
      "args"  => ["foo", "bar"]
    }
    @instrument = Pace::Instruments::Redistat.new(:queue => "pace")
  end

  it "calls record on processed hook" do
    @instrument.processed.should == 0
    worker = Pace::Worker.new("pace")
    worker.send(:run_hook, :processed, @job)
    @instrument.processed.should == 1
  end

  describe ".record" do
    it "increments processed" do
      @instrument.processed.should == 0
      @instrument.record(@job)
      @instrument.record(@job)
      @instrument.processed.should == 2
    end

    it "updates class processed count" do
      @instrument.record(@job)
      @instrument.record(@job)
      @instrument.classes["FakeJob"].should == 2
    end

    it "updates last_job_at" do
      @instrument.processed.should == 0
      @instrument.record(@job)

      now = Time.now
      Time.stub!(:time).and_return(now)

      @instrument.record(@job)
      @instrument.last_job_at.should == now.to_i
    end
  end

  describe ".save" do
    it "resets the number of processed jobs and last_job_at timestamp" do
      now = Time.now
      Time.stub!(:now).and_return(now)

      @instrument.record(@job)

      EM.run {
        @instrument.save { EM.stop }
      }

      @instrument.processed.should == 0
      @instrument.last_job_at.should be_nil
    end

    it "each call ticks the queue's updated_at timestamp, even if no jobs were processed" do
      @instrument.record(@job)

      later = Time.now + 10
      Time.stub!(:now).and_return(later)

      EM.run {
        @instrument.save { EM.stop }
      }

      Resque.redis.hget("pace:info:queues:pace", "updated_at").should == later.to_i.to_s
      Resque.redis.hget("pace:info:queues:pace", "last_job_at").should < later.to_i.to_s
    end

    it "doesn't set last_job_at to 0" do
      Resque.redis.hset("pace:info:queues:pace", "last_job_at", Time.now.to_i)

      # Save
      EM.run { @instrument.save { EM.stop } }
      @instrument.last_job_at.should be_nil
      Resque.redis.hget("pace:info:queues:pace", "last_job_at").to_i.should > 0
    end
  end
end
