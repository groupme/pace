# At first I was like
# module Pace
#   class ThrottledWorker < Worker
#     def initialize(queue, limit, refresh_interval = 1)
#       @credits = @limit = limit
#
#       EM::add_periodic_timer(refresh_interval) do
#         @credits = @limit
#         fetch_next_job
#       end
#
#       super(queue)
#     end
#
#     alias :fetch_next_job_without_throttling :fetch_next_job
#
#     def fetch_next_job
#       until @credits < 1
#         @credits -= 1
#         EM.next_tick { fetch_next_job_without_throttling }
#       end
#     end
#   end
# end
# Then I was like
module Pace
  class ThrottledWorker < Worker
    def initialize(queue, limit, refresh_interval = 1)
      @credits = @limit = limit

      EM::add_periodic_timer(refresh_interval) do
        EM.next_tick { fetch_next_job } if @credits < 1
        @credits = @limit
      end

      super(queue)
    end

    alias :fetch_next_job_without_throttling :fetch_next_job

    def fetch_next_job
      return if @credits < 1
      @credits -= 1
      fetch_next_job_without_throttling
    end
  end
end
