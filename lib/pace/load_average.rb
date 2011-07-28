module Pace
  module LoadAverage
    INTERVAL  = PACE_HEARTBEAT
    FSHIFT    = 11
    FIXED_1   = 1 << FSHIFT
    EXP_1     = 1884.0 # 1/exp(5sec/1min) as fixed-point
    EXP_5     = 2014.0 # 1/exp(5sec/5min)
    EXP_15    = 2037.0 # 1/exp(5sec/15min)
    $ticks    = 0
    $load     = [0.0, 0.0, 0.0, 0.0] # sec, min, 5 min, 15 min

    class << self
      def compute
        per_second = $ticks / INTERVAL
        $load[0] = per_second
        $load[1] = average($load[1], EXP_1, per_second)
        $load[2] = average($load[2], EXP_5, per_second)
        $load[3] = average($load[3], EXP_15, per_second)
        $ticks = 0
        log "load averages: #{$load.join(' ')}"
        $load
      end

      def tick
        $ticks += 1
      end

      private

      def average(load, exp, n)
        load *= exp
        load += n*(FIXED_1-exp)
        load = (((load * 1000).to_i >> FSHIFT) / 1000.0)
        round(load, 2)
      end

      def round(float, precision = nil)
        if precision
          magnitude = 10.0 ** precision
          (float * magnitude).round / magnitude
        else
          float.round
        end
      end
    end
  end
end
