module Pace
  module LoadAverage
    INTERVAL  = 5.0 # sec
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
        $load
      end

      def average(load, exp, n)
        load *= exp
        load += n*(FIXED_1-exp)
        ((load * 1000).to_i >> FSHIFT) / 1000.0
      end

      def tick
        $ticks += 1
      end
    end
  end
end
