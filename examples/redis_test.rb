require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  if job["args"][0]["disconnect"]
    worker.instance_eval { @redis.close_connection }
  end

  Pace.logger.info(job.inspect)
end
