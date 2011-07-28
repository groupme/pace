require "spec_helper"

describe Pace::MultiQueueWorker do
  describe "#initialize" do
    it "allows multiple queues to be set" do
      worker = Pace::MultiQueueWorker.new(["normal", "high"])
      worker.queues.should == ["resque:queue:normal", "resque:queue:high"]

      worker = Pace::MultiQueueWorker.new("normal,high")
      worker.queues.should == ["resque:queue:normal", "resque:queue:high"]
    end
  end

  describe "#start" do
    before do
      @worker = Pace::MultiQueueWorker.new([Work.queue, Play.queue])
    end

    it "pop jobs from multiple queues until stopped" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Play, :n => "a")
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Play, :n => "b")
      Resque.enqueue(Work, :n => 3)
      Resque.enqueue(Play, :n => "c")
      Resque.enqueue(Work, :n => 4)
      Resque.enqueue(Play, :n => "d")
      Resque.enqueue(Work, :n => 5)
      Resque.enqueue(Play, :n => "e")

      results = []

      @worker.start do |job|
        n = job["args"].first["n"]
        results << n
        EM.stop if results.size == 10
      end

      results.should == [1, "a", 2, "b", 3, "c", 4, "d", 5, "e"]
    end
  end
end
