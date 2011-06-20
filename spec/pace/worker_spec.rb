require "spec_helper"

describe Pace::Worker do
  class Work
    def self.queue
      "pace"
    end
  end

  before do
    Resque.dequeue(Work)
  end

  describe "#initialize" do
    describe "sets the Redis connection options" do
      before do
        @connection = double(EM::Connection)
      end

      it "uses 127.0.0.1:6379/0 by default" do
        EM::Protocols::Redis.should_receive(:connect).with(
          :host     => "127.0.0.1",
          :port     => 6379,
          :password => nil,
          :db       => 0
        ).and_return(@connection)

        worker = Pace::Worker.new :queue => "normal"
        worker.stub(:fetch_next_job).and_return { EM.stop_event_loop }
        worker.start
        worker.redis.should == @connection
      end

      it "can use a custom URL string" do
        EM::Protocols::Redis.should_receive(:connect).with(
          :host     => "some.host.local",
          :port     => 9999,
          :password => "secret",
          :db       => 1
        ).and_return(@connection)

        worker = Pace::Worker.new :url => "redis://user:secret@some.host.local:9999/1", :queue => "normal"
        worker.stub(:fetch_next_job).and_return { EM.stop_event_loop }
        worker.start
        worker.redis.should == @connection
      end

      it "can be set using the PACE_REDIS environment variable" do
        original_redis = ENV["PACE_REDIS"]
        ENV["PACE_REDIS"] = "redis://user:secret@some.host.local:9999/1"

        EM::Protocols::Redis.should_receive(:connect).with(
          :host     => "some.host.local",
          :port     => 9999,
          :password => "secret",
          :db       => 1
        ).and_return(@connection)

        worker = Pace::Worker.new :queue => "normal"
        worker.stub(:fetch_next_job).and_return { EM.stop_event_loop }
        worker.start
        worker.redis.should == @connection

        ENV["PACE_REDIS"] = original_redis
      end
    end

    describe "sets the queue_name" do
      before do
        EM::Protocols::Redis.stub(:connect).and_return(double(EM::Connection))
      end

      context "when the given name has no colons" do
        it "prepends the Resque default queue 'namespace'" do
          worker = Pace::Worker.new(:queue => "normal")
          worker.queue_name.should == "resque:queue:normal"
        end
      end

      context "when the given name has colons" do
        it "does not prepend anything (absolute)" do
          worker = Pace::Worker.new(:queue => "my:special:queue")
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
      @worker = Pace::Worker.new(:queue => "pace")
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

  describe "#on_error" do
    it "creates a callback to run if there's an error while processing a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)
      exception = RuntimeError.new("FAIL")

      worker = Pace::Worker.new(:queue => "pace")
      worker.on_error do |job, error|
        job.should == {"class" => "Work", "args" => [{"n" => 1}]}.to_json
        error.should == exception
      end

      worker.start do |job|
        n = job["args"].first["n"]
        raise exception    if n == 1
        EM.stop_event_loop if n == 2
      end
    end
  end

  describe "#shutdown" do
    it "stops the event loop on the next attempt to fetch a job" do
      Resque.enqueue(Work, :n => 1)
      Resque.enqueue(Work, :n => 2)

      results = []

      worker = Pace::Worker.new(:queue => "pace")
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

      @worker = Pace::Worker.new(:queue => "pace")
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
end
