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
      Pace.redis_options = {:url => "redis://user:secret@some.host.local:9999/1"}

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
end
