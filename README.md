# Pace - A Resque Reactor #

More docs to come...

In short, the goals are:

 * Performance
 * Transparency via instrumentation (TODO)

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

## Single Queue

    Pace.start(:queue => "normal") do |job|
      ...
    end

## Multiple Queues

Like Resque, you can specify multiple queues:

    Pace.start(:queues => ["low", "high"]) do |job|
      ...
    end

## Pausing and resuming

If you need to pause a pace, simply:

    Pace.pause
    
And when ready:

    Pace.resume
    
    