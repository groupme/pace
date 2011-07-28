# Pace (and EventMachine) works best when your job can block
# on a socket and proceed to process jobs (almost) concurrently.
#
# A good explanation can be found here:
#   http://www.igvita.com/2008/05/27/ruby-eventmachine-the-speed-demon/

require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  start_time = Time.now

  http = EM::Protocols::HttpClient.request(
    :host    => "localhost",
    :port    => 9000,
    :request => "/"
  )
  http.callback do |r|
    worker.log(job.inspect, start_time)
  end
end
