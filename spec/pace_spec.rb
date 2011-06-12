require "spec_helper"

describe Pace do
  describe ".start" do
    it "is a shortcut for instantiating and running a Pace::Worker" do
      expected_block = Proc.new {}

      worker = Pace::Worker.new("normal")
      worker.should_receive(:start).with(&expected_block)
      Pace::Worker.should_receive(:new).with("normal").and_return(worker)

      Pace.start("normal", &expected_block)
    end
  end
end
