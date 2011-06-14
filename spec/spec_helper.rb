require "rubygems"
require "bundler"
Bundler.require(:default, :test)

require "pace"

RSpec.configure do |config|
  config.before(:each) do
    Pace.stub(:logger).and_return(Logger.new("/dev/null"))
  end
end
