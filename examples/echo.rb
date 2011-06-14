require "pace"

puts "Echoing jobs to console..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  Pace.log(job.inspect, Time.now)
end
