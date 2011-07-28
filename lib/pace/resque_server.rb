# Extend Resque::Server to add tabs.
module Pace
  module ResqueServer

    def self.included(base)
      base.class_eval {
        helpers do
          def pace_info
            info = Resque.redis.hgetall("pace:info")
            {
              :updated_at => info["updated_at"] && Time.at(info["updated_at"].to_i),
              :processed  => info["processed"],
              :queues     => pace_queues,
              :workers    => []
            }
          end

          def pace_queues
            queues = {}
            Resque.redis.keys("pace:info:queues:*").each do |key|
              queue = key.gsub("pace:info:queues:", "")
              info = Resque.redis.hgetall(key)
              queues[queue] = {
                :updated_at   => info["updated_at"] && Time.now(info["updated_at"].to_i),
                :last_job_at  => info["last_job_at"] && Time.now(info["last_job_at"].to_i),
                :processed    => info["processed"]
              }
            end
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
