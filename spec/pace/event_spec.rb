require "spec_helper"

describe Pace::Event do
  describe "#run" do
    it "simply invokes a set of hooks" do
      hook_1_run = false
      hook_2_run = false

      hook_1 = Proc.new { hook_1_run = true }
      hook_2 = Proc.new { hook_2_run = true }

      event = Pace::Event.new([hook_1, hook_2])
      event.run

      hook_1_run.should be_true
      hook_2_run.should be_true
    end

    it "supplies args to the hooks" do
      hook_run = false
      hook = Proc.new do |a, b|
        if a == 1 && b == 2
          hook_run = true
        end
      end

      event = Pace::Event.new([hook], 1, 2)
      event.run

      hook_run.should be_true
    end

    context "when a callback is supplied" do
      it "only fires when all hooks call #finished! on their Hook argument" do
        hook_1_run   = false
        hook_2_run   = false
        callback_run = false

        hook_1 = Proc.new { |hook| hook_1_run = true; hook.finished! }
        hook_2 = Proc.new { |hook| hook_2_run = true; hook.finished! }

        event = Pace::Event.new([hook_1, hook_2]) { callback_run = true }
        event.run

        hook_1_run.should be_true
        hook_2_run.should be_true
        callback_run.should be_true
      end

      it "does not fire if a hook fails to call #finished!" do
        hook_run     = false
        callback_run = false

        hook = Proc.new { |hook| hook_run = true }

        event = Pace::Event.new([hook]) { callback_run = true }
        event.run

        hook_run.should be_true
        callback_run.should be_false
      end

      it "fires the callback anyway if none of the hooks accepts the Hook argument" do
        hook_1_run   = false
        hook_2_run   = false
        callback_run = false

        hook_1 = Proc.new { hook_1_run = true }
        hook_2 = Proc.new { hook_2_run = true }

        event = Pace::Event.new([hook_1, hook_2]) { callback_run = true }
        event.run

        hook_1_run.should be_true
        hook_2_run.should be_true
        callback_run.should be_true
      end

      it "works with mixed-type hooks" do
        hook_1_run   = false
        hook_2_run   = false
        callback_run = false

        hook_1 = Proc.new { |hook| hook_1_run = true; hook.finished! }
        hook_2 = Proc.new { hook_2_run = true }

        event = Pace::Event.new([hook_1, hook_2]) { callback_run = true }
        event.run

        hook_1_run.should be_true
        hook_2_run.should be_true
        callback_run.should be_true
      end
    end
  end
end
