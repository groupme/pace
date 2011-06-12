# Pace - A Resque Reactor #

In short, the goals are:

 * Performance
 * Transparency via instrumentation

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
