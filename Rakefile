require 'bundler'
Bundler::GemHelper.install_tasks

namespace :examples do
  $: << File.join(File.dirname(__FILE__), "examples")

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
