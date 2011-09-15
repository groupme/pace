require "spec_helper"

describe Pace do
  describe ".redis_connect" do
    let(:connection) { double(EM::Connection) }

    it "returns a Redis connection" do
      EM::Hiredis.should_receive(:connect).with(nil).and_return(connection)
      Pace.redis_connect.should == connection
    end

    it "uses Pace.redis_url if set" do
      Pace.redis_url = "redis://user:secret@some.host.local:9999/1"
      EM::Hiredis.should_receive(:connect).with(Pace.redis_url).and_return(connection)
      Pace.redis_connect.should == connection
      Pace.redis_url = nil
    end
  end
end
