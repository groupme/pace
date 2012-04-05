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

## Redis

Pace connects to Redis with a URI that's looked up in the following order:

 * Pace.redis_url attr_accessor
 * REDIS_URL environment variable
 * Defaults to 127.0.0.1:6379/0

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

## Errors

Pace attempts to keep the reactor going at all costs with explicit rescues
and EM's catch-all error handler. A hook is provided for errors so that
action can be taken:

    worker.add_hook(:error) do |json, error|
      message = error.message

      # The job JSON can be nil if the error is raised in a callback.
      message << json if json

      Pace.logger.warn(message)
    end

Hooks can also be attached at the class-level, which affects all workers.

    Pace::Worker.add_hook(:error, handler)

Finally, an Airbrake hook is provided that will notify Airbrake on all
exceptions:

    require "pace/airbrake"

    Pace::Worker.add_hook(:error, Pace::Airbrake.hook)
