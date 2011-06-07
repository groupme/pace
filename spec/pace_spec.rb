require "rubygems"
require "bundler"
Bundler.require(:default, :test)

require "pace"

describe Pace do
  class Work
    def self.queue
      "normal"
    end
  end

  describe ".start" do
    it "yields a serialized Resque job for the given queue" do
      Resque.enqueue(Work, :foo => 1, :bar => 2)

      Pace.start("normal") do |job|
        job["class"].should == "Work"
        job["args"].should == [{"foo" => 1, "bar" => 2}]
        EM.stop_event_loop
      end
    end

    it "continues to pop jobs until stopped" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)
      Resque.enqueue(Work, :n => 4)
      Resque.enqueue(Work, :n => 5)

      results = []

      Pace.start("normal") do |job|
        n = job["args"].first["n"]
        results << n
        EM.stop_event_loop if n == 5
      end

      results.should == [1, 2, 3, 4, 5]
    end
  end
end
