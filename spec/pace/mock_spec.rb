require "spec_helper"
require "pace/mock"

describe Pace::Mock do
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

  before do
    Resque.dequeue(Work)
    Resque.dequeue(Play)
  end

  after do
    Pace::Mock.disable
  end

  describe ".enable" do
    it "sets up the mock, which simply passes down Resque jobs and closes the event loop" do
      Pace::Mock.enable
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      results = []
      worker = Pace::Worker.new("work")
      worker.start { |job| results << job }
      results.should == [
        {"class" => "Work", "args" => [{"n" => 1}]},
        {"class" => "Work", "args" => [{"n" => 2}]}
      ]

      # Clears out the queue
      more_results = []
      worker.start { |job| more_results << job }
      more_results.should be_empty
    end

    it "works with multiple queues" do
      Pace::Mock.enable
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Play, :n => "a")
      Resque.enqueue(Play, :n => "b")

      results = []
      worker = Pace::Worker.new(["work", "play"])
      worker.start { |job| results << job }
      results.should == [
        {"class" => "Work", "args" => [{"n" => 1}]},
        {"class" => "Work", "args" => [{"n" => 2}]},
        {"class" => "Play", "args" => [{"n" => "a"}]},
        {"class" => "Play", "args" => [{"n" => "b"}]},
      ]

      # Clears out the queues
      more_results = []
      worker.start { |job| more_results << job }
      more_results.should be_empty
    end

    it "works after disabling" do
      Pace::Mock.enable
      Pace::Mock.disable
      Pace::Mock.enable

      Resque.enqueue(Work, :n => 2)

      results = []
      worker = Pace::Worker.new("work")
      worker.start do |job|
        results << job
      end
      results.should == [{"class" => "Work", "args" => [{"n" => 2}]}]
    end
  end

  describe ".disable" do
    it "tears down the mock and re-institutes the event loop" do
      Pace::Mock.enable
      Pace::Mock.disable
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      results = []
      worker = Pace::Worker.new("work")
      worker.start do |job|
        results << job
        EM.stop_event_loop
      end

      results.should have(1).items
    end
  end
end
