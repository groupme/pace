require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  Pace.logger.info(job.inspect)
end
