# To gain concurrent processing on jobs that don't block on
# sockets, we can use EM.defer to run in background threads.

require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  start_time = Time.now

  operation = proc {
    rand(10).times { sleep 0.1 }
  }
  callback = proc { |result|
    Pace.log(job.inspect, start_time)
  }

  EM.defer operation, callback
end
