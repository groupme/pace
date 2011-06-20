# Benchmark Resque
#
# This was performed by running:
#
#     $ rake bench:resque
#     $ COUNT=1000 rake bench:jobs
#
# By default, it spins up ten workers locally, logging to bench/resque.log. A dummy
# node.js server was propped up to simply respond with 200 OK.
#
# For 1000 jobs:
#   18.33s (avg. 5 runs, 18.33ms/job)
#
# For 50,000 jobs:
#   870.81s (just 1 run, but I got stuff to do, 17.42ms/job),
#     memory sitting at ~15MB per worker process (10 total)

require "net/http"
require "logger"

class ResqueHttp
  def self.queue
    "normal"
  end

  def self.perform(args)
    start_time = Time.now
    args = args.map { |k,v| "#{k}=#{v}" }
    args = args.join("&")

    Net::HTTP.start("localhost", 9000) do |http|
      http.get("/?#{args}")
    end

    logger.info "http://localhost:9000/?#{args} #{"(%0.6fs)" % (Time.now - start_time)}"
  end

  def self.logger
    @logger ||= Logger.new(File.join(File.dirname(__FILE__), "resque.log"))
  end
end
