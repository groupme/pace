require 'bundler'
require "resque/tasks"
require "rspec/core/rake_task"

Bundler::GemHelper.install_tasks

$: << File.dirname(__FILE__)

namespace :examples do
  desc "Simply echo jobs to the console"
  task :echo do
    require "examples/echo"
  end

  desc "Serial processing when the block doesn't defer"
  task :sleep do
    require "examples/sleep"
  end

  desc "Concurrent processing using EM.defer"
  task :defer do
    require "examples/defer"
  end

  desc "Concurrent processing by blocking on an HTTP connection"
  task :http do
    require "examples/http"
  end
end

namespace :bench do
  desc "Bench Pace just running through its loop"
  task :pace_simple do
    require "bench/pace_simple"
  end

  desc "Bench Pace with New Relic monitoring"
  task :pace_newrelic do
    require "bench/pace_newrelic"
  end

  desc "Bench HTTP calls through Pace"
  task :pace_http do
    ENV["PACE_QUEUE"] = "normal"
    require "bench/pace_http"
  end

  desc "Bench HTTP calls through Resque"
  task :resque_http do
    ENV["COUNT"]   = "10"
    ENV["QUEUE"]   = "normal"
    # ENV["VERBOSE"] = "1"

    Rake::Task["resque:workers"].invoke
  end

  desc "Inject jobs for benchmarking"
  task :jobs do
    require "resque"
    require "bench/resque_http"

    count = (ENV["COUNT"] || 100).to_i
    count.times do |n|
      Resque.enqueue(ResqueHttp, :n => n)
    end
  end
end

# For benchmark purposes
namespace :resque do
  task :setup do
    require "bench/resque_http"
  end
end

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
end

task :default => :spec
