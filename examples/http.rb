require "pace"

puts "Waiting for jobs..."

Pace.start(ENV["QUEUE"] || "normal") do |job|
  http = EM::Protocols::HttpClient.request(
    :host    => "www.google.com",
    :port    => 80,
    :request => "/"
  )
  http.callback do |r|
    time = Time.now
    timestamp = "#{time.strftime("%I:%M:%S")}.#{time.usec}"
    puts "Finished [#{timestamp}]: #{job.inspect}"
  end
end
