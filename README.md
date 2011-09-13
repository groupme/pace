# Pace - A Resque Reactor #

Pace provides a high-throughput way to process Resque jobs inside an
EventMachine reactor.

When combined with EM::HttpRequest you can send __thousands of
requests per second__ to a remote web service.

Tested under:

* REE 1.8.7
* MRI 1.9.2 (best memory performance)

## Examples ##

To have fun with the examples, fire one up and then start
enqueuing Resque jobs:

    $ rake examples:http

    $ irb
    > require "rubygems"
    > require "resque"
    > class MyJob; def self.queue; "normal"; end; end
    > Resque.enqueue(MyJob)
    > 10.times { |n| Resque.enqueue(MyJob, :n => n) }


In a separate process, start up a worker:

    require 'pace'

    worker = Pace::Worker.new("normal")
    worker.start do |job|
      klass = job["class"]
      options = job["args"].first

      # do work with options
    end

## Throttling

It's very easy to overwhelm a remote service with pace. You can specify
the maximum number of jobs to consume per second.

    Pace::Worker.new("queue", :jobs_per_second => 100)

## Pause/Resume

If you need to pause a worker (for example, during remote service failure):

    worker.pause

And when ready:

    worker.resume

You can also pause for a set period of time. The worker will resume
automatically.

    worker.pause(0.5) # 500ms

## Instrumentation

### Load Average

By default, pace will log its load averages every 10 seconds:

    load averages: 0.0 0.0 0.0 0.0

The format is:

    load averages: <sec> <1min> <5min> <15min>

The algorithm is borrowed from linux load average computation and only gives a
rough estimate as time gets larger, but the per-second load average sample
is completely accurate.
