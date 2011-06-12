require "spec_helper"

describe Pace::Worker do
  class Work
    def self.queue
      "normal"
    end
  end

  describe "#initialize" do
    describe "sets the queue_name" do
      context "when the given name has no colons" do
        it "prepends the Resque default queue 'namespace'" do
          worker = Pace::Worker.new("normal")
          worker.queue_name.should == "resque:queue:normal"
        end
      end

      context "when the given name has colons" do
        it "does not prepend anything (absolute)" do
          worker = Pace::Worker.new("my:special:queue")
          worker.queue_name.should == "my:special:queue"
        end
      end

      context "when the queue argument is nil" do
        before do
          @pace_queue = ENV["PACE_QUEUE"]
        end

        after do
          ENV["PACE_QUEUE"] = @pace_queue
        end

        it "falls back to the PACE_QUEUE environment variable" do
          ENV["PACE_QUEUE"] = "high"
          worker = Pace::Worker.new
          worker.queue_name.should == "resque:queue:high"

          ENV["PACE_QUEUE"] = "my:special:queue"
          worker = Pace::Worker.new
          worker.queue_name.should == "my:special:queue"
        end

        it "throws an exception if PACE_QUEUE is nil" do
          ENV["PACE_QUEUE"] = nil
          expect { Pace::Worker.new }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "#start" do
    before do
      @worker = Pace::Worker.new("normal")
    end

    it "yields a serialized Resque jobs" do
      Resque.enqueue(Work, :foo => 1, :bar => 2)

      @worker.start do |job|
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

      @worker.start do |job|
        n = job["args"].first["n"]
        results << n
        EM.stop_event_loop if n == 5
      end

      results.should == [1, 2, 3, 4, 5]
    end
  end
end
