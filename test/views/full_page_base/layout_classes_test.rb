# frozen_string_literal: true

require("test_helper")

# Tests for `Views::FullPageBase::LayoutClasses`: setters that
# populate `content_for(:container_class)` / `(:left_columns)` /
# `(:right_columns)` / `(:content_padding)`, plus the matching
# `default_*` defaulters `Views::FullPageBase#around_template` runs
# after the action template has finished.
#
# Goal of these tests is to pin two contracts:
#
#   1. Each setter writes the right class string for each enum input.
#   2. When BOTH a setter and its defaulter touch a slot,
#      `flush: true` makes the setter win — slots don't accumulate
#      across calls.
#
# Each test renders a one-off page subclass whose `view_template`
# calls the LayoutClasses method under test and then records the
# resulting `content_for` slot value in a class-level Hash. Reading
# the slot from inside the view's own render context sidesteps
# Rails' "fresh view_context per call" behavior — `view_context.
# content_for(...)` after `render(...)` returns would be peeking at
# a different view_context instance.
class Views::FullPageBase::LayoutClassesTest < ComponentTestCase
  # ----- container_class setter -----------------------------------

  def test_container_class_default_text_writes_container_text
    assert_equal("container-text", captured_slot(:container_class) do
      container_class
    end)
  end

  def test_container_class_wide_writes_container_wide
    assert_equal("container-wide", captured_slot(:container_class) do
      container_class(:wide)
    end)
  end

  def test_container_class_text_image_writes_container_text_image
    assert_equal("container-text-image",
                 captured_slot(:container_class) do
                   container_class(:text_image)
                 end)
  end

  def test_container_class_unknown_writes_container_full
    assert_equal("container-full", captured_slot(:container_class) do
      container_class(:something_unknown)
    end)
  end

  # ----- container_class defaulter + flush behavior ---------------

  def test_default_after_explicit_does_not_aggregate
    # Action sets :wide; FullPageBase's around_template then runs
    # default_container_class. The defaulter SHOULD early-return
    # because the slot is set. If `flush: true` were missing on the
    # setter, content would aggregate to "container-widecontainer-..."
    # or similar.
    assert_equal("container-wide", captured_slot(:container_class) do
      container_class(:wide)
      default_container_class
    end)
  end

  def test_default_alone_writes_text
    assert_equal("container-text", captured_slot(:container_class) do
      default_container_class
    end)
  end

  # ----- column_classes setter -----------------------------------

  def test_column_classes_nine_three_writes_split_left_right
    left, right = captured_slots(:left_columns, :right_columns) do
      column_classes(:nine_three)
    end

    assert_equal("col-xs-12 col-md-9 col-lg-8", left)
    assert_equal("col-xs-12 col-md-3 col-lg-4", right)
  end

  def test_column_classes_default_writes_full_width_both_sides
    left, right = captured_slots(:left_columns, :right_columns) do
      column_classes
    end

    assert_equal("col-xs-12", left)
    assert_equal("col-xs-12", right)
  end

  def test_column_classes_six_even_writes_half_width_both_sides
    left, right = captured_slots(:left_columns, :right_columns) do
      column_classes(:six_even)
    end

    assert_equal("col-xs-12 col-lg-6", left)
    assert_equal("col-xs-12 col-lg-6", right)
  end

  def test_column_classes_explicit_then_default_does_not_aggregate
    left, right = captured_slots(:left_columns, :right_columns) do
      column_classes(:nine_three)
      default_column_classes
    end

    assert_equal("col-xs-12 col-md-9 col-lg-8", left)
    assert_equal("col-xs-12 col-md-3 col-lg-4", right)
  end

  # ----- content_padding setter ----------------------------------

  def test_content_padding_no_panels_writes_p_3
    assert_equal("p-3", captured_slot(:content_padding) do
      content_padding(:no_panels)
    end)
  end

  def test_content_padding_panels_writes_p_0
    assert_equal("p-0", captured_slot(:content_padding) do
      content_padding(:panels)
    end)
  end

  def test_content_padding_default_for_show_action_is_p_0
    stub_action_name("show")

    assert_equal("p-0", captured_slot(:content_padding) do
      content_padding
    end)
  end

  def test_content_padding_default_for_new_action_is_p_3
    stub_action_name("new")

    assert_equal("p-3", captured_slot(:content_padding) do
      content_padding
    end)
  end

  def test_content_padding_explicit_then_default_does_not_aggregate
    stub_action_name("new")

    assert_equal("p-0", captured_slot(:content_padding) do
      content_padding(:panels)
      default_content_padding
    end)
  end

  private

  # `controller.action_name` defaults to "test" on the test
  # controller. Override per-test where the assertion depends on
  # the value (i.e. the `content_padding` default branch).
  def stub_action_name(name)
    controller.define_singleton_method(:action_name) { name }
  end

  # Render a one-off page that runs `block` in its `view_template`,
  # then records `content_for(slot)` from inside the same render
  # context. Returns the captured value.
  def captured_slot(slot, &block)
    captured_slots(slot, &block).first
  end

  # Same shape as `captured_slot` but for multiple slots — read all
  # values inside a single render context, returns as positional
  # array.
  def captured_slots(*slots, &setup_block)
    captured = []
    page_class = Class.new(Views::FullPageBase) do
      define_method(:view_template) do
        instance_eval(&setup_block)
        captured.concat(slots.map { |s| content_for(s) })
      end
      def around_template
        yield
      end
    end
    render(page_class.new)
    captured
  end
end
