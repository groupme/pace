require 'bundler'
require "resque/tasks"
Bundler::GemHelper.install_tasks

$: << File.join(File.dirname(__FILE__), "bench")
$: << File.join(File.dirname(__FILE__), "examples")

namespace :examples do
  desc "Simply echo jobs to the console"
  task :echo do
    require "echo"
  end

  desc "Serial processing when the block doesn't defer"
  task :sleep do
    require "sleep"
  end

  desc "Concurrent processing using EM.defer"
  task :defer do
    require "defer"
  end

  desc "Concurrent processing by blocking on an HTTP connection"
  task :http do
    require "http"
  end
end

namespace :bench do
  desc "Fire up Pace for benchmarking"
  task :pace do
    ENV["PACE_QUEUE"] = "normal"
    require "pace_http"
  end

  desc "Fire up Resque for benchmarking"
  task :resque do
    ENV["COUNT"]   = "10"
    ENV["QUEUE"]   = "normal"
    # ENV["VERBOSE"] = "1"

    Rake::Task["resque:workers"].invoke
  end

  desc "Inject jobs for benchmarking"
  task :jobs do
    require "resque"
    require "resque_http"

    count = (ENV["COUNT"] || 100).to_i
    count.times do |n|
      Resque.enqueue(ResqueHttp, :n => n)
    end
  end
end

# For benchmark purposes
namespace :resque do
  task :setup do
    require "resque_http"
  end
end
