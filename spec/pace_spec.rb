require "spec_helper"

describe Pace do
  describe ".redis_connect" do
    let(:connection) { double(EM::Connection) }

    it "returns a Redis connection" do
      EM::Protocols::Redis.should_receive(:connect).with(
        :host     => "127.0.0.1",
        :port     => 6379,
        :password => nil,
        :db       => 0
      ).and_return(connection)

      Pace.redis_connect.should == connection
    end

    it "uses any options (set either directly or via Pace.start)" do
      Pace.options = {:url => "redis://user:secret@some.host.local:9999/1"}

      EM::Protocols::Redis.should_receive(:connect).with(
        :host     => "some.host.local",
        :port     => 9999,
        :password => "secret",
        :db       => 1
      ).and_return(connection)

      Pace.redis_connect.should == connection
    end

    it "can be set using the PACE_REDIS environment variable" do
      original_redis = ENV["PACE_REDIS"]
      ENV["PACE_REDIS"] = "redis://user:secret@some.host.local:9999/1"

      EM::Protocols::Redis.should_receive(:connect).with(
        :host     => "some.host.local",
        :port     => 9999,
        :password => "secret",
        :db       => 1
      ).and_return(connection)

      Pace.redis_connect.should == connection

      ENV["PACE_REDIS"] = original_redis
    end
  end

  describe ".start" do
    it "sets the options used by .redis_connect" do
      worker = double(Pace::Worker)
      worker.stub(:start)
      Pace::Worker.stub(:new).and_return(worker)

      Pace.start(:queue => "pace", :url => "redis://user:secret@some.host.local:9999/1")
      Pace.options.should == {
        :url => "redis://user:secret@some.host.local:9999/1"
      }
    end

    it "starts up a Worker with the provided queue" do
      block = Proc.new { "WOOOO!" }

      worker = double(Pace::Worker)
      worker.should_receive(:start).with(&block)
      Pace::Worker.should_receive(:new).with("pace").and_return(worker)

      Pace.start({:queue => "pace"}, &block)
    end

    it "accpets multiple queues" do
      block = Proc.new { "WOOOO!" }

      worker = double(Pace::Worker)
      worker.should_receive(:start).with(&block)
      Pace::Worker.should_receive(:new).with(["pace", "picante"]).and_return(worker)

      Pace.start({:queues => ["pace", "picante"]}, &block)
    end
  end

  describe ".enqueue" do
    class CallbackJob
      def self.queue
        "callback"
      end
    end

    it "adds a new, Resque-compatible job into the specified queue" do
      options = {:x => 1, :y => 2}

      EM.run {
        Pace.enqueue(CallbackJob.queue, CallbackJob, options) {
          EM.stop_event_loop
        }
      }

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

  describe ".pause" do
    it "pauses the worker" do
      worker = double(Pace::Worker, :start => true)
      worker.should_receive(:pause).once
      Pace::Worker.stub(:new).and_return(worker)

      Pace.start
      Pace.pause
    end
  end

  describe ".resume" do
    it "resumes the worker" do
      worker = double(Pace::Worker, :start => true)
      worker.should_receive(:resume).once
      Pace::Worker.stub(:new).and_return(worker)

      Pace.start
      Pace.resume
    end
  end
end
