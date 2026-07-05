# frozen_string_literal: true

require("test_helper")

class HelpDispatcherTest < ComponentTestCase
  # Omitting `type:` stays on the `Components::Help` class itself (no
  # subclass dispatch) — the plain `help-block` shape.
  def test_no_type_kwarg_returns_help_instance
    result = Components::Help.new

    assert_instance_of(Components::Help, result)
  end

  def test_type_tooltip_routes_to_tooltip_subclass
    result = Components::Help.new(type: :tooltip, label: "(?)")

    assert_instance_of(Components::Help::Tooltip, result)
  end

  def test_type_collapse_block_routes_to_collapse_block_subclass
    result = Components::Help.new(type: :collapse_block, target_id: "x")

    assert_instance_of(Components::Help::CollapseBlock, result)
  end

  def test_type_collapse_info_trigger_routes_to_subclass
    result = Components::Help.new(type: :collapse_info_trigger,
                                  target_id: "x")

    assert_instance_of(Components::Help::CollapseInfoTrigger, result)
  end

  # An unknown `type:` key raises ArgumentError immediately.
  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Help.new(type: :bogus_unknown_type)
    end
  end
end
