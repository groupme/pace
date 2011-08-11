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

    it "works if run inside an existing reactor" do
      Resque.enqueue(Work)

      results = []

      EM.run do
        worker = Pace::Worker.new(Work.queue)
        worker.start do |job|
          results << job
          EM.stop
        end
      end

      results.should == [{"class" => "Work", "args" => []}]
    end

    it "can process multiple queues with multiple instances of workers" do
      5.times { |n| Resque.enqueue(Work, :n => n) }
      5.times { |n| Resque.enqueue(Play, :n => n) }

      results = {
        "Work"  => 0,
        "Play"  => 0,
        "Total" => 0
      }

      EM.run do
        worker_1 = Pace::Worker.new(Work.queue)
        worker_2 = Pace::Worker.new(Play.queue)

        block = Proc.new do |job|
          results[job["class"]] += 1
          results["Total"] += 1

          EM.stop if results["Total"] == 10
        end

        worker_1.start(&block)
        worker_2.start(&block)
      end

      results["Work"].should == 5
      results["Play"].should == 5
      results["Total"].should == 10
    end

    it "continues to fetch jobs if the Redis connection drops inside the job callback" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      results = []

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        n = job["args"][0]["n"]
        results << n

        case n
        when 1
          worker.instance_eval { @redis.close_connection }
        when 3
          worker.shutdown
        end
      end

      results.should == [1, 2, 3]
    end

    it "continues to fetch jobs if the Redis connection drops when waiting for blpop to return" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      results = []

      worker = Pace::Worker.new(Work.queue)
      worker.add_hook(:start) do
        EM.add_timer(0.1) do
          worker.instance_eval { @redis.close_connection }
        end
      end
      worker.start do |job|
        n = job["args"][0]["n"]
        results << n
        sleep 0.1
        worker.shutdown if n == 3
      end

      results.should == [1, 2, 3]
    end
  end

  describe "event hooks" do
    it "can be defined for start, error, and shutdown" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      called_hooks = []

      worker = Pace::Worker.new(Work.queue)
      worker.add_hook(:start) do
        called_hooks.should be_empty
        called_hooks << :start
      end

      worker.add_hook(:error) do |json, error|
        called_hooks.should == [:start]
        called_hooks << :error
        error.message.should == "FAIL"
      end

      worker.add_hook(:shutdown) do
        called_hooks.should == [:start, :error]
        called_hooks << :shutdown
      end

      worker.start do |job|
        n = job["args"].first["n"]

        if n == 1
          raise "FAIL"
        else
          worker.shutdown
        end
      end

      called_hooks.should == [:start, :error, :shutdown]
    end

    it "can be defined globally on Pace::Worker" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      called_hooks = []

      Pace::Worker.add_hook(:start) do
        called_hooks.should be_empty
        called_hooks << :start
      end

      Pace::Worker.add_hook(:error) do |json, error|
        called_hooks.should == [:start]
        called_hooks << :error
        error.message.should == "FAIL"
      end

      Pace::Worker.add_hook(:shutdown) do
        called_hooks.should == [:start, :error]
        called_hooks << :shutdown
      end

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        n = job["args"].first["n"]

        if n == 1
          raise "FAIL"
        else
          worker.shutdown
        end
      end

      called_hooks.should == [:start, :error, :shutdown]
    end
  end

  describe "#shutdown" do
    # With Pace::Instruments::Redistat mixed in, the shutdown hook delays the
    # actual stop until all the Redis calls finish. Thus, exact time when the
    # reactor shuts down is unknown. Hence the somewhat flaky test.
    it "stops the event loop and calls shutdown hooks" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)
      Resque.enqueue(Work, :n => 4)
      Resque.enqueue(Work, :n => 5)

      results = []

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        worker.shutdown
        results << job["args"].first["n"]
      end

      # Never runs the second job
      results.should_not be_empty
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

    it "pauses for specified time period" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      Resque.enqueue(Work, :n => 3)

      results = []

      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        n = job["args"].first["n"]
        if n == 1
          worker.pause(0.1) # sleep for 100ms
        elsif n >= 3
          worker.shutdown
        end
        results << Time.now.to_f
      end

      # Check if we actually paused
      (results[1] - results[0]).should > 0.1
      (results[2] - results[0]).should > 0.1
    end

    it "does not pause if already paused" do
      Resque.enqueue(Work, :n => 1)
      worker = Pace::Worker.new(Work.queue)
      worker.start do |job|
        worker.pause(0.1)
        worker.pause(0.1).should be_false
        worker.shutdown
      end
    end
  end
end
