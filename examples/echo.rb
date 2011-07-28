require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  Pace.log(job.inspect, Time.now)
end
