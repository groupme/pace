require "spec_helper"

describe Pace::Worker do
  class Work
    def self.queue
      "pace" # change to 'work'
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

  describe "#initialize" do
    describe "builds the queue name" do
      context "when the given name has no colons" do
        it "prepends the Resque default queue 'namespace'" do
          worker = Pace::Worker.new("normal")
          worker.queues.should == ["resque:queue:normal"]
        end
      end

      context "when the given name has colons" do
        it "does not prepend anything (like an absolute path)" do
          worker = Pace::Worker.new("my:special:queue")
          worker.queues.should == ["my:special:queue"]
        end
      end

      context "when a global namespace is attached to Pace" do
        before { Pace.namespace = "test" }
        after  { Pace.namespace = nil }

        it "prepends the namespace in either case" do
          worker = Pace::Worker.new("normal")
          worker.queues.should == ["test:resque:queue:normal"]

          worker = Pace::Worker.new("special:queue")
          worker.queues.should == ["test:special:queue"]
        end
      end

      context "when the queue argument is nil" do
        before { @original_pace_queue = ENV["PACE_QUEUE"] }
        after  { ENV["PACE_QUEUE"] = @original_pace_queue }

        it "falls back to the PACE_QUEUE environment variable" do
          ENV["PACE_QUEUE"] = "high"
          worker = Pace::Worker.new
          worker.queues.should == ["resque:queue:high"]

          ENV["PACE_QUEUE"] = "my:special:queue"
          worker = Pace::Worker.new
          worker.queues.should == ["my:special:queue"]

          ENV["PACE_QUEUE"] = "low,high"
          worker = Pace::Worker.new
          worker.queues.should == ["resque:queue:low", "resque:queue:high"]

          ENV["PACE_QUEUE"] = "my:special:queue,other:special:queue"
          worker = Pace::Worker.new
          worker.queues.should == ["my:special:queue", "other:special:queue"]
        end

        it "throws an exception if PACE_QUEUE is nil" do
          ENV["PACE_QUEUE"] = nil
          expect { Pace::Worker.new }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "#start" do
    describe "with a single queue" do
      before do
        Resque.dequeue(Work)
        @worker = Pace::Worker.new("pace")
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

      it "rescues any errors in the passed block" do
        Resque.enqueue(Work, :n => 1)
        Resque.enqueue(Work, :n => 2)
        Resque.enqueue(Work, :n => 3)

        results = []

        @worker.start do |job|
          n = job["args"].first["n"]

          raise "FAIL" if n == 1
          results << n
          EM.stop_event_loop if n == 3
        end

        results.should == [2, 3]
      end
    end

    describe "with multiple queues" do
      before do
        Resque.dequeue(Work)
        Resque.dequeue(Play)
        @worker = Pace::Worker.new(["pace", "play"])
      end

      it "continues to pop jobs until stopped" do
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
          EM.stop_event_loop if results.size == 10
        end

        results.should == [1, "a", 2, "b", 3, "c", 4, "d", 5, "e"]
      end
    end
  end

  describe "#on_error" do
    it "creates callbacks to run if there's an error while processing a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      exception = RuntimeError.new("FAIL")

      worker = Pace::Worker.new("pace")
      errors = []

      # Error handler 1
      worker.on_error do |job, error|
        errors << error
      end

      # Error handler 2
      worker.on_error do |job, error|
        errors << error
      end

      worker.start do |job|
        n = job["args"].first["n"]
        raise exception    if n == 1
        EM.stop_event_loop if n == 2
      end

      errors.should == [exception, exception]
    end

    it "also fires global callbacks defined on Pace" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      exception = RuntimeError.new("FAIL")

      worker = Pace::Worker.new("pace")
      errors = []

      # Global handler
      Pace.on_error { |job, error| errors << error }

      # Local handler
      worker.on_error { |job, error| errors << error }

      worker.start do |job|
        n = job["args"].first["n"]
        raise exception    if n == 1
        EM.stop_event_loop if n == 2
      end

      errors.should == [exception, exception]
    end
  end

  describe "#shutdown" do
    it "stops the event loop on the next attempt to fetch a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      results = []

      worker = Pace::Worker.new("pace")
      worker.start do |job|
        worker.shutdown
        results << job["args"].first["n"]
      end

      # Never runs the second job
      results.should == [1]
    end
  end

  describe "signal handling" do
    before do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      @worker = Pace::Worker.new("pace")
    end

    ["QUIT", "TERM", "INT"].each do |signal|
      it "handles SIG#{signal}" do
        results = []

        @worker.start do |job|
          n = job["args"].first["n"]
          Process.kill(signal, $$) if n == 1
          results << n
        end

        # trap seems to interrupt the event loop randomly, so it does not appear
        # possible to determine exactly how many jobs will be processed
        results.should_not be_empty
      end
    end
  end

  describe "pausing and resuing" do
    before do
      @worker = Pace::Worker.new("pace")
    end

    it "pauses the reactor and resumes it" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      results = []

      worker = Pace::Worker.new("pace")
      worker.start do |job|
        n = job["args"].first["n"]
        if n == 1
          worker.pause
          EM.add_timer(0.1) { worker.resume } # wait a little
        elsif n >= 3
          worker.shutdown
        end
        results << Time.now.to_f
      end

      # Check if we actually paused
      (results[1] - results[0]).should > 0.1
      (results[2] - results[0]).should > 0.1
    end
  end
end
