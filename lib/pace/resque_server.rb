# Extend Resque::Server to add tabs.
module Pace
  module ResqueServer
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::NumberHelper

    def self.included(base)
      base.class_eval {
        helpers do
          def pace_info
            info = Resque.redis.hgetall("pace:info")
            queues = pace_queues
            last_job_at = queues.map { |key, info| info[:last_job_at] }.compact.sort.last
            {
              :updated_at   => info["updated_at"] && Time.at(info["updated_at"].to_i),
              :last_job_at  => last_job_at,
              :processed    => info["processed"],
              :classes      => pace_classes,
              :queues       => queues,
              :workers      => []
            }
          end

          def pace_queues
            queues = {}
            Resque.redis.keys("pace:info:queues:*").each do |key|
              queue = key.gsub("pace:info:queues:resque:queue:", "")
              if info = Resque.redis.hgetall(key)
                queues[queue] = {
                  :updated_at   => info["updated_at"] && Time.at(info["updated_at"].to_i),
                  :last_job_at  => info["last_job_at"] && Time.at(info["last_job_at"].to_i),
                  :processed    => info["processed"]
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
  include Pace::ResqueServer
end
