require "spec_helper"

describe Pace do
  describe ".start" do
    it "is a shortcut for instantiating and running a Pace::Worker" do
      expected_block = Proc.new {}

      worker = double(Pace::Worker)
      worker.should_receive(:start).with(&expected_block)
      Pace::Worker.should_receive(:new).with(
        :url   => "redis://127.0.0.1:6379/0",
        :queue => "normal",
      ).and_return(worker)

      Pace.start(:url => "redis://127.0.0.1:6379/0", :queue => "normal", &expected_block)
    end
  end
end
