# Instrument your workers with New Relic
#
# The agent will look for a config file in the usual pace -- config/newrelic.yml.
# The environment will be set to RAILS_ENV or RUBY_ENV by default.

begin
  require "newrelic_rpm"
rescue LoadError
  raise "Can't find 'newrelic_rpm' gem. Please add it to your Gemfile or install it."
end

Pace::Worker.class_eval do
  include NewRelic::Agent::Instrumentation::ControllerInstrumentation

  def perform_with_trace(job)
    perform_action_with_newrelic_trace(
      :name       => "perform",
      :class_name => job["class"],
      :category   => "OtherTransaction/Pace",
      :params     => job
    ) do
      perform_without_trace(job)
    end
  end

  alias :perform_without_trace :perform
  alias :perform :perform_with_trace
end

Pace::Worker.add_hook(:start) do
  NewRelic::Agent.manual_start(:dispatcher => :pace, :log => Pace.logger)
end

Pace::Worker.add_hook(:shutdown) do
  NewRelic::Agent.shutdown
end
