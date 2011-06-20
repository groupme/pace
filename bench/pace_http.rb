# Benchmark Pace
#
# Performed by running:
#
#     $ rake bench:pace
#     $ COUNT=1000 rake bench:jobs
#
# This was setup to hit a dumb node.js server that simply responds with 200 OK.
#
# For 1000 jobs:
#   1.783s (avg. 5 runs, 1.78ms/job)
#
# For 50,000 jobs:
#   68.708s (avg. 5 runs, 1.37ms/job), memory topped out at a steady 21.3MB

require "pace"

Pace.logger = Logger.new(File.join(File.dirname(__FILE__), "pace.log"))
Pace.log("Starting #{'%0.6f' % Time.now}")

Pace.start do |job|
  start_time = Time.now
  args = job["args"][0].map { |k,v| "#{k}=#{v}" }
  args = args.join("&")

  http = EM::Protocols::HttpClient.request(
    :host    => "localhost",
    :port    => 9000,
    :request => "/?#{args}"
  )
  http.callback do |r|
    Pace.log("http://localhost:9000/?#{args}", start_time)
  end
end
