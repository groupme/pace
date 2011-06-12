# Our work in this example does not defer nor block on a socket,
# so jobs will be processed serially, finishing one before starting
# the next.
#
# This should be avoided.

require "pace"

puts "Waiting for jobs..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  rand(10).times do
    sleep 0.1
  end

  time = Time.now
  timestamp = "#{time.strftime("%I:%M:%S")}.#{time.usec}"
  puts "Finished [#{timestamp}]: #{job.inspect}"
end
