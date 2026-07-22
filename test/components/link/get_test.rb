# frozen_string_literal: true

require("test_helper")

class LinkGetTest < ComponentTestCase
  def setup
    super
    @herbarium = herbaria(:nybg_herbarium)
    @path = routes.herbarium_path(id: @herbarium.id)
  end

  def test_renders_anchor_with_text_name
    html = render_link(name: "View", target: @path)

    assert_html(html, "a[href='#{@path}']", text: "View")
    assert_no_html(html, "form")
  end

  def test_icon_kwarg_renders_icon_inside_anchor
    html = render_link(name: :edit.ti, target: @path, icon: :edit)

    assert_html(html, "a span.glyphicon")
    assert_html(html, "a span.sr-only", text: :edit.ti)
  end

  def test_block_renders_inside_anchor
    html = render(block_wrapper)

    assert_html(html, "a[href='#{@path}']")
    assert_html(html, "a span.block-sentinel", text: "from block")
  end

  def test_block_supersedes_button_content
    html = render(block_wrapper)

    # icon: was not passed to the wrapper — confirm no stray glyphicon
    assert_no_html(html, "a span.glyphicon")
  end

  def test_no_block_falls_back_to_button_content
    html = render_link(name: "Fallback", target: @path)

    assert_html(html, "a[href='#{@path}']", text: "Fallback")
  end

  def test_new_tab_adds_target_and_rel
    html = render_link(name: "External", target: @path, new_tab: true)

    assert_html(html,
                "a[href='#{@path}'][target='_blank']" \
                "[rel='noopener noreferrer']")
  end

  def test_strip_button_variant_renders_plain_link_without_btn_frame
    html = render_link(name: "View", target: @path, button: :strip)

    assert_html(html, "a[href='#{@path}']", text: "View")
    assert_no_html(html, "a.btn")
  end

  def test_back_show_appended_for_eligible_controller_on_show_action
    record = herbarium_records(:coprinus_comatus_nybg_spec)
    controller.define_singleton_method(:controller_name) { "herbarium_records" }
    controller.define_singleton_method(:action_name) { "show" }

    html = render(Components::Link::Get.new(name: "Edit", target: record,
                                            action: :edit))

    expected = routes.edit_herbarium_record_path(id: record.id, back: :show)
    assert_html(html, "a[href='#{expected}']")
  end

  def test_back_index_appended_for_eligible_controller_on_index_action
    record = herbarium_records(:coprinus_comatus_nybg_spec)
    controller.define_singleton_method(:controller_name) { "herbarium_records" }
    controller.define_singleton_method(:action_name) { "index" }

    html = render(Components::Link::Get.new(name: "Edit", target: record,
                                            action: :edit))

    expected = routes.edit_herbarium_record_path(id: record.id, back: :index)
    assert_html(html, "a[href='#{expected}']")
  end

  def test_no_back_param_for_ineligible_controller
    record = herbarium_records(:coprinus_comatus_nybg_spec)
    controller.define_singleton_method(:controller_name) { "observations" }
    controller.define_singleton_method(:action_name) { "show" }

    html = render(Components::Link::Get.new(name: "Edit", target: record,
                                            action: :edit))

    expected = routes.edit_herbarium_record_path(id: record.id)
    assert_html(html, "a[href='#{expected}']")
  end

  private

  # Wrapper component so the block runs inside a Phlex render context.
  class WithBlock < Components::Base
    def initialize(path:)
      super()
      @path = path
    end

    def view_template
      render(Components::Link::Get.new(name: "Go", target: @path)) do
        span(class: "block-sentinel") { plain("from block") }
      end
    end
  end

  def block_wrapper
    WithBlock.new(path: @path)
  end

  def render_link(name:, target:, **)
    render(Components::Link::Get.new(name: name, target: target, **))
  end
end
