require "spec_helper"

describe Pace::Worker do
  describe "#initialize" do
    context "when the given name has no colons" do
      it "prepends the Resque default queue 'namespace'" do
        worker = Pace::Worker.new("normal")
        worker.queue.should == "resque:queue:normal"
      end
    end

    context "when the given name has colons" do
      it "does not prepend anything (like an absolute path)" do
        worker = Pace::Worker.new("my:special:queue")
        worker.queue.should == "my:special:queue"
      end
    end

    context "when a global namespace is attached to Pace" do
      before { Pace.namespace = "test" }
      after  { Pace.namespace = nil }

      it "prepends the namespace in either case" do
        worker = Pace::Worker.new("normal")
        worker.queue.should == "test:resque:queue:normal"

        worker = Pace::Worker.new("special:queue")
        worker.queue.should == "test:special:queue"
      end
    end

    context "when the queue argument is nil" do
      before { @original_pace_queue = ENV["PACE_QUEUE"] }
      after  { ENV["PACE_QUEUE"] = @original_pace_queue }

      it "falls back to the PACE_QUEUE environment variable" do
        ENV["PACE_QUEUE"] = "high"
        worker = Pace::Worker.new
        worker.queue.should == "resque:queue:high"

        ENV["PACE_QUEUE"] = "my:special:queue"
        worker = Pace::Worker.new
        worker.queue.should == "my:special:queue"
      end

      it "throws an exception if PACE_QUEUE is nil" do
        ENV["PACE_QUEUE"] = nil
        expect { Pace::Worker.new }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#start" do
    before do
      @worker = Pace::Worker.new(Work.queue)
    end

    it "yields a serialized Resque jobs" do
      Resque.enqueue(Work, :foo => 1, :bar => 2)

      @worker.start do |job|
        job["class"].should == "Work"
        job["args"].should == [{"foo" => 1, "bar" => 2}]
        EM.stop
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
        EM.stop if n == 5
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
        EM.stop if n == 3
      end

      results.should == [2, 3]
    end
  end

  describe "#on_error" do
    it "creates callbacks to run if there's an error while processing a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      exception = RuntimeError.new("FAIL")

      worker = Pace::Worker.new(Work.queue)
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
        EM.stop if n == 2
      end

      errors.should == [exception, exception]
    end

    it "also fires global callbacks defined on Pace::Worker" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      exception = RuntimeError.new("FAIL")

      worker = Pace::Worker.new(Work.queue)
      errors = []

      # Global handler
      Pace::Worker.on_error { |job, error| errors << error }

      # Local handler
      worker.on_error { |job, error| errors << error }

      worker.start do |job|
        n = job["args"].first["n"]
        raise exception    if n == 1
        EM.stop if n == 2
      end

      errors.should == [exception, exception]
    end
  end

  describe "#shutdown" do
    it "stops the event loop on the next attempt to fetch a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      results = []

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        worker.shutdown
        results << job["args"].first["n"]
      end

      # Never runs the second job
      results.should == [1]
    end
  end

  describe "#enqueue" do
    class CallbackJob
      def self.queue
        "callback"
      end
    end

    it "adds a new, Resque-compatible job into the specified queue" do
      options = {:x => 1, :y => 2}

      Resque.enqueue(Work)

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        worker.enqueue(CallbackJob.queue, CallbackJob, options) { EM.stop }
      end

      new_job = Resque.pop(CallbackJob.queue)
      new_job.should == {
        "class" => "CallbackJob",
        "args"  => [{"x" => 1, "y" => 2}]
      }

      # It's identical to a job added w/ Resque (important!)
      Resque.enqueue(CallbackJob, options)
      resque_job = Resque.pop(CallbackJob.queue)
      resque_job.should == new_job
    end
  end

  describe "signal handling" do
    before do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      @worker = Pace::Worker.new(Work.queue)
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

  describe "pausing and resuming" do
    before do
      @worker = Pace::Worker.new(Work.queue)
    end

    it "pauses the reactor and resumes it" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      results = []

      worker = Pace::Worker.new(Work.queue)
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
