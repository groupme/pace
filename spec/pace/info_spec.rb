require 'spec_helper'

describe Pace::Info do
  before do
    @job = {
      "class" => "FakeJob",
      "args"  => ["foo", "bar"]
    }
    Pace::Info.reset
  end

  describe ".log" do
    it "increments processed" do
      Pace::Info.processed.should == 0
      Pace::Info.log("pace", @job)
      Pace::Info.log("pace", @job)
      Pace::Info.processed.should == 2
    end

    it "updates class processed count" do
      Pace::Info.log("pace", @job)
      Pace::Info.log("pace", @job)
      Pace::Info.classes["FakeJob"].should == 2
    end

    it "updates queue last_job_at" do
      Pace::Info.processed.should == 0
      Pace::Info.log("pace", @job)

      now = Time.now
      Time.stub!(:time).and_return(now)

      Pace::Info.log("pace", @job)
      Pace::Info.queues["pace"][:last_job_at].should == now.to_i
    end

    it "updates queue processed count" do
      Pace::Info.processed.should == 0
      Pace::Info.log("pace", @job)
      Pace::Info.log("pace", @job)
      Pace::Info.queues["pace"][:processed].should == 2
    end
  end

  describe ".save" do
    it "resets the number of processed jobs and the last_job_at timestamp but keeps the queue around" do
      now = Time.now
      Time.stub!(:now).and_return(now)

      Pace::Info.log("pace", @job)
      Pace::Info.queues["pace"][:processed].should == 1
      Pace::Info.queues["pace"][:last_job_at].should == now.to_i

      Pace::Info.log("high", @job)
      Pace::Info.queues["high"][:processed].should == 1
      Pace::Info.queues["high"][:last_job_at].should == now.to_i

      EM.run_block { Pace::Info.save }

      Pace::Info.queues["pace"][:processed].should == 0
      Pace::Info.queues["pace"][:last_job_at].should be_nil

      Pace::Info.queues["high"][:processed].should == 0
      Pace::Info.queues["high"][:last_job_at].should be_nil
    end

    it "each call ticks the queue's updated_at timestamp, even if no jobs were processed" do
      now = Time.now
      Time.stub!(:now).and_return(now)

      # Populate at least one queue
      Pace::Info.log("pace", @job)
      Pace::Info.queues["pace"][:processed].should == 1

      EM.run do
        Pace::Info.save { EM.stop }
      end

      Resque.redis.hget("pace:info:queues:pace", "updated_at").should == now.to_i.to_s

      Time.stub!(:now).and_return(now + 10)
      Pace::Info.class_eval { @redis = nil }

      EM.run do
        Pace::Info.save { EM.stop }
      end

      Resque.redis.hget("pace:info:queues:pace", "updated_at").should == (now + 10).to_i.to_s
    end
  end
end
