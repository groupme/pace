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
