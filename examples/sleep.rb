# Our work in this example does not defer nor block on a socket,
# so jobs will be processed serially, finishing one before starting
# the next.
#
# This should be avoided.

require "pace"

puts "Waiting for jobs..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  start_time = Time.now
  rand(10).times { sleep 0.1 }
  Pace.log(job.inspect, start_time)
end
