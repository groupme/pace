require "spec_helper"

describe "Pace with Hoptoad" do
  it "calls Hoptoad if a job fails" do
    require "pace/hoptoad"
    HoptoadNotifier.should_receive(:notify_or_ignore)

    failed = false
    Resque.enqueue(Work)
    Resque.enqueue(Work)

    worker = Pace::Worker.new(Work.queue)
    worker.start do |job|
      unless failed
        failed = true
        raise "FAIL"
      else
        EM.stop
      end
    end
  end
end
