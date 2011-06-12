# To gain concurrent processing on jobs that don't block on
# sockets, we can use EM.defer to run in background threads.

require "pace"

puts "Waiting for jobs..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  EM.defer do
    rand(10).times do
      sleep 0.1
    end

    time = Time.now
    timestamp = "#{time.strftime("%I:%M:%S")}.#{time.usec}"
    puts "Finished [#{timestamp}]: #{job.inspect}"
  end
end
