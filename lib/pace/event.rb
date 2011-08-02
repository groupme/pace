module Pace
  class Event
    include EM::Deferrable

    attr_accessor :type

    def initialize(hooks, *args, &block)
      @hooks = hooks.map { |hook| Hook.new(self, hook, *args) }
      callback(&block)
    end

    def run
      @hooks.each(&:run)
    end

    def hook_finished!
      if @hooks.all?(&:finished?)
        succeed
      end
    end
  end

  class Hook
    def initialize(event, hook, *args)
      @event    = event
      @hook     = hook
      @args     = args
      @finished = false
    end

    def run
      if @hook.arity > @args.size
        @hook.call(*@args, self)
      else
        @hook.call(*@args)
        finished!
      end
    end

    def finished!
      @finished = true
      @event.hook_finished!
    end

    def finished?
      @finished
    end
  end
end
