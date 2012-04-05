require "spec_helper"
require "pace/airbrake"

describe "Pace with Airbrake" do
  it "notifies Airbrake if a job fails" do
    error_params = nil

    ::Airbrake.should_receive(:notify).and_return do |params|
      error_params = params
      EM.stop
    end

    Resque.enqueue(Work)

    worker = Pace::Worker.new(Work.queue)
    worker.add_hook(:error, Pace::Airbrake.hook)
    worker.start do |job|
      raise "FAIL"
    end

    error_params[:error_class].should == "RuntimeError"
    error_params[:error_message].should == "RuntimeError: FAIL"
    error_params[:parameters][:json].should_not be_blank
  end

  it "notifies Airbrake for errors raised in callbacks" do
    error_params = nil

    ::Airbrake.should_receive(:notify).and_return do |params|
      error_params = params
      EM.stop
    end

    Resque.enqueue(Work)

    EM.run do
      redis = Pace.redis_connect

      worker = Pace::Worker.new(Work.queue)
      worker.add_hook(:error, Pace::Airbrake.hook)
      worker.start do |job|
        redis.ping do
          raise "FAIL"
        end
      end
    end

    error_params[:error_class].should == "RuntimeError"
    error_params[:error_message].should == "RuntimeError: FAIL"
    error_params[:parameters][:json].should be_blank
  end
end
