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
end
