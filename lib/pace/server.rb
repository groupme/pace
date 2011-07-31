# Extend Resque::Server to add tabs.
module Pace
  module Server
    def self.included(base)
      base.class_eval {
        helpers do
          if defined?(ActionView)
            include ActionView::Helpers::DateHelper
            include ActionView::Helpers::NumberHelper
          else
            def distance_of_time_in_words(time, other)
              time.to_s
            end

            def number_with_delimiter(number)
              number
            end
          end

          def pace_info
            info = Resque.redis.hgetall("pace:info")
            queues = pace_queues
            last_job_at = queues.map { |q, i| i[:last_job_at] }.compact.sort.last
            {
              :processed    => info["processed"].to_i,
              :updated_at   => info["updated_at"] && Time.at(info["updated_at"].to_i),
              :last_job_at  => last_job_at,
              :classes      => pace_classes,
              :workers      => pace_workers,
              :queues       => queues
            }
          end

          def pace_queues
            queues = {}
            Resque.redis.keys("pace:info:queues:*").each do |key|
              queue = key.gsub("pace:info:queues:", "")
              if info = Resque.redis.hgetall(key)
                queues[queue] = {
                  :updated_at   => info["updated_at"] && Time.at(info["updated_at"].to_i),
                  :last_job_at  => info["last_job_at"] && Time.at(info["last_job_at"].to_i),
                  :processed    => info["processed"].to_i
                }
              end
            end
            queues
          end

          def pace_classes
            classes = {}
            Resque.redis.hgetall("pace:info:classes").each do |name, processed|
              classes[name] = processed.to_i
            end
            Hash[classes.sort]
          end

          def pace_workers
            workers = {}
            Resque.redis.keys("pace:info:workers:*").each do |key|
              id = key.gsub("pace:info:workers:", "")
              if info = Resque.redis.hgetall(key)
                workers[id] = {
                  :created_at   => info["created_at"] && Time.at(info["created_at"].to_i),
                  :updated_at   => info["updated_at"] && Time.at(info["updated_at"].to_i),
                  :command      => info["command"],
                  :processed    => info["processed"].to_i
                }
              end
            end
            workers
          end

          # reads a 'local' template file.
          def local_template(path)
            # Is there a better way to specify alternate template locations with sinatra?
            File.read(File.join(File.dirname(__FILE__), "server/views/#{path}"))
          end
        end

        get '/pace' do
          erb local_template('pace.erb')
        end
      }
    end

  end
end

Resque::Server.tabs << 'Pace'
Resque::Server.class_eval do
  include Pace::Server
end
