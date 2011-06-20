require "pace"

Pace.start(:queue => (ENV["PACE_QUEUE"] || "normal")) do |job|
  Pace.log(job.inspect, Time.now)
end
