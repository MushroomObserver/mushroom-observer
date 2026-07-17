# frozen_string_literal: true

require("test_helper")

# Covers config/initializers/solid_cable_silence_subscribe.rb: the
# per-subscription `SELECT MAX(id)` in Solid Cable's Listener#add_channel
# must run inside the same #with_polling_volume silencer the gem uses
# for its recurring polling queries.
class SolidCableSubscribeSilencerTest < UnitTestCase
  # Probe class standing in for the gem's Listener -- records call
  # order so we can assert add_channel runs INSIDE the silencer.
  class ProbeListener
    attr_reader :calls

    def initialize
      @calls = []
    end

    def add_channel(_channel, _on_success)
      @calls << :add_channel
    end

    private

    def with_polling_volume
      @calls << :silencer_entered
      yield
      @calls << :silencer_exited
    end

    prepend SolidCableSubscribeSilencer
  end

  def test_add_channel_runs_inside_the_polling_silencer
    probe = ProbeListener.new

    probe.add_channel(:some_channel, nil)

    assert_equal([:silencer_entered, :add_channel, :silencer_exited],
                 probe.calls)
  end

  def test_module_is_prepended_to_the_real_listener
    listener = ActionCable::SubscriptionAdapter::SolidCable::Listener

    assert_includes(listener.ancestors, SolidCableSubscribeSilencer)
    assert_equal(SolidCableSubscribeSilencer,
                 listener.instance_method(:add_channel).owner)
  end
end
