module Pace
  class Stats
    include Redistat::Model

    class << self
      def name
        "pace:stats"
      end

      def google_chart_cols(queues)
        cols = ["{id: 'time', label: 'Time', type: 'string'}"]
        queues.each do |queue|
          cols << "{id: '#{queue}', label: '#{queue}', type: 'number'}"
        end
        cols.join(',')
      end

      def google_chart_rows(queues, interval = :min)
        results = []
        if interval == :min
          points = 720
          label_index = 120
          stats = Pace::Stats.find(
            "jobs",
            12.hours.ago,
            1.hour.from_now,
            :interval => :min,
            :depth    => :min
          )
        elsif interval == :hour
          points = 168
          label_index = 24
          stats = Pace::Stats.find(
            "jobs",
            7.days.ago,
            1.hour.from_now,
            :interval => :hour,
            :depth    => :hour
          )
        end

        stats.map do |r|
          results << [r.date] + queues.map {|q| r[q.to_sym].to_i}
        end

        format = (interval == :min) ? "%k:%M" : "%a %m/%d"
        rows = []
        0.upto(points - 1).each do |row_index|
          cols = []
          counts = results[row_index]
          date = counts.shift.utc # discard date
          if show_axis_label?(interval, date)
            cols << "{v:'#{date.strftime(format)}'}"
          else
            cols << "{v:''}"
          end
          counts.each do |count|
            cols << "{v:#{count}}"
          end
          rows << "{c:[#{cols.join(',')}]}"
        end
        rows.join(',')
      end

      def show_axis_label?(interval, date)
        if interval == :min
          date.min == 0 && date.hour % 2 == 0
        else
          date.hour == 0 && date.min == 0
        end
      end
    end
  end
end
