require "pace"

puts "Echoing jobs to console..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  time = Time.now
  timestamp = "#{time.strftime("%I:%M:%S")}.#{time.usec}"
  puts "Received [#{timestamp}]: #{job.inspect}"
end
