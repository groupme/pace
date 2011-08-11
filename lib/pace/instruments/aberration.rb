# Usage
#
#     instrument = Pace::Instruments::Aberration.new(
#       :observations         => data,
#       :deviation_tolerance  => 0.05,
#       :deviation_limit      => 4,
#       :deviation_window     => 5
#     )
#     instrument.aberrant? # => true or false
#
# Visualize the data
#
#     instrument = Pace::Instrument::Aberration.new(data)
#
#     observations = instrument.smooth(instrument.observations)
#     forecast = instrument.smooth(instrument.forecast)
#     upper = forecast.map { |i| i * (1 + instrument.tolerance) })
#     lower = forecast.map { |i| i * (1 - instrument.tolerance) })
#
#     File.open("/Users/bkeene/Desktop/smoothing.csv", "w") do |file|
#       (0...data.size).each do |i|
#         row = [
#           i,
#           observations[i],
#           forecast[i],
#           upper[i],
#           lower[i]
#         ]
#         file.write(row.join(',') + "\n")
#       end
#     end
#
# Plot it in gnuplot
#
# gnuplot> set datafile delimiter ','
# gnuplot> plot "smoothing.csv" using 1:2 title "observations" with lines smooth bezier,\
#   "smoothing.csv" using 1:3 title "forecast" with lines smooth bezier,\
#   "smoothing.csv" using 1:4 title "upper" with lines,\
#   "smoothing.csv" using 1:5 title "lower" with lines
#
module Pace
  module Instruments
    class Aberration < Base
      require "gsl"

      INTERVAL = 60

      attr_reader :observations,
                  :forecast

      # Aberrant Behavior Detection
      #
      # options
      #
      #   :observations           => array or integer
      #   :samples_per_observaton => 6 (one observation per minute)*
      #   :alpha                  => level coefficient (0..1)
      #   :beta                   => trend coefficient (0..1)
      #   :gamma                  => season coefficient (0..1)
      #   :period                 => a season consists of L periods (minium of 2L observations required)
      #   :deviation_window       => number observations to inspect for deviations
      #   :deviation_count        => number of deviations for aberration
      #   :deviation_tolerance    => percentage deviation from forecast (0..1)
      #
      def initialize(options = {}, &block)
        @options = options
        @callback = block
        if options[:observations].kind_of?(Array)
          @observations = @options[:observations]
        else
          @observations = Array.new(@options[:observations], nil)
        end

        @options[:intervals_per_observation]  ||= 1
        @options[:alpha]                      ||= 0.1
        @options[:beta]                       ||= 0.05
        @options[:gamma]                      ||= 0.01
        @options[:period]                     ||= 10
        @options[:deviation_limit]            ||= 4
        @options[:deviation_window]           ||= 5
        @options[:deviation_tolerance]        ||= 0.05

        Pace::Worker.add_hook(:processed) { |job| record(job) }
        Pace::Worker.add_hook(:start) { EM.add_periodic_timer(INTERVAL) { save } }
      end

      def record(job)
        @job_counter ||= 0
        @job_counter += 1
      end

      def save
        if aberrant?
          message = "aberration detected (#{@options[:deviation_limit]} deviations in last #{@options[:deviation_window]} observations)"
          Pace.log(message)
          @callback.call(true) if @callback
        else
          @callback.call(false) if @callback
        end
        store_observation
      end

      def aberrant?
        return false unless forecast_ready?
        @forecast  = compute_forecast
        w = @options[:deviation_window]
        t = @options[:deviation_tolerance]
        s_o = smooth(observations)
        s_f = smooth(forecast)

        deviations = 0
        (-w..-1).each do |i|
          o = s_o[i]
          f = s_f[i]
          if o > (f * (1 + t))
            deviations += 1
          elsif o < (f * (1 - t))
            deviations += 1
          end
        end

        deviations >= @options[:deviation_limit]
      end

      def forecast_ready?
        return false if observations.size < 2 * @options[:period]
        return false if observations.any?(&:nil?)
        true
      end

      def smooth(series)
        n = series.size - 1
        ncoeffs = 64 # also higher seems to fit better, but is slower
        nbreak = ncoeffs - 2 # dunno what this does
        x_range = 15.0 # for some reason

        bw = GSL::BSpline.alloc(4, nbreak) # 4th order. Can't seem to change
        b = GSL::Vector.alloc(ncoeffs)
        x = GSL::Vector.alloc(n)
        y = GSL::Vector.alloc(n)
        xx = GSL::Matrix.alloc(n, ncoeffs)

        for i in 0...n do
          xi = (x_range/(n-1)/1)*i
          yi = series[i]

          x[i] = xi
          y[i] = yi
        end

        bw.knots_uniform(0.0, x_range)

        for i in 0...n do
          xi = x[i]
          bw.eval(xi, b)
          for j in 0...ncoeffs do
            xx[i,j] = b[j]
          end
        end

        c, cov, chisq = GSL::MultiFit.linear(xx, y)
        x2 = GSL::Vector.linspace(0, x_range, n)
        y2 = GSL::Vector.alloc(n)
        x2.each_index do |i|
          bw.eval(x2[i], b)
          yi, yerr = GSL::MultiFit::linear_est(b, c, cov)
          y2[i] = yi
        end

        y2.to_a
      end

      private

      def store_observation
        @intervals ||= 0
        @intervals += 1
        if @intervals == @options[:intervals_per_observation]
          observations.shift
          observations.push(@job_counter)
          @intervals = 0
          @job_counter = 0
        end
      end

      def compute_forecast
        HoltWinters.forecast(
          observations,
          @options[:alpha],
          @options[:beta],
          @options[:gamma],
          @options[:period],
          1 # forecast 1 period into the future
        )
      end
    end
  end
end
