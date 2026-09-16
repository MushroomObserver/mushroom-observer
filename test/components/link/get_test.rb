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

    assert_html(html, "a svg.mo-icon-edit")
    assert_html(html, "a span.sr-only", text: :edit.ti)
  end

  def test_block_renders_inside_anchor
    html = render(block_wrapper)

    assert_html(html, "a[href='#{@path}']")
    assert_html(html, "a span.block-sentinel", text: "from block")
  end

  def test_block_supersedes_button_content
    html = render(block_wrapper)

    # icon: was not passed to the wrapper — confirm no stray icon
    assert_no_html(html, "a svg.mo-icon")
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

    html = render_link(name: "Edit", target: record, action: :edit)

    expected = routes.edit_herbarium_record_path(id: record.id, back: :show)
    assert_html(html, "a[href='#{expected}']")
  end

  def test_back_index_appended_for_eligible_controller_on_index_action
    record = herbarium_records(:coprinus_comatus_nybg_spec)
    controller.define_singleton_method(:controller_name) { "herbarium_records" }
    controller.define_singleton_method(:action_name) { "index" }

    html = render_link(name: "Edit", target: record, action: :edit)

    expected = routes.edit_herbarium_record_path(id: record.id, back: :index)
    assert_html(html, "a[href='#{expected}']")
  end

  def test_no_back_param_for_ineligible_controller
    record = herbarium_records(:coprinus_comatus_nybg_spec)
    controller.define_singleton_method(:controller_name) { "observations" }
    controller.define_singleton_method(:action_name) { "show" }

    html = render_link(name: "Edit", target: record, action: :edit)

    expected = routes.edit_herbarium_record_path(id: record.id)
    assert_html(html, "a[href='#{expected}']")
  end

  # ---- tab: shortcut ---------------------------------------------------

  def test_tab_shortcut_pulls_name_target_and_icon_from_tab
    name = names(:fungi)
    html = render_tab_link(tab: ::Tab::Name::Edit.new(name: name))

    assert_html(html, "a[href='#{routes.edit_name_path(name.id)}']",
                text: :show_name_edit_name.l.as_displayed)
    assert_html(html, "a svg.mo-icon-edit")
  end

  def test_explicit_name_and_target_override_tab
    name = names(:fungi)
    html = render_tab_link(tab: ::Tab::Name::Edit.new(name: name),
                           name: "Custom", target: @path)

    assert_html(html, "a[href='#{@path}']", text: "Custom")
  end

  def test_missing_tab_and_name_or_target_raises
    assert_raises(ArgumentError) { Components::Link::Get.new(name: "Only") }
    assert_raises(ArgumentError) { Components::Link::Get.new(target: @path) }
  end

  # ---- stateful icon+label swap -----------------------------------------

  def test_active_icon_and_content_render_second_pair_with_stateful_link
    html = render_link(name: "Subscribe", target: @path, icon: :tracking,
                       active_icon: :check, active_content: "Subscribed")

    assert_html(html, "a.stateful-link svg.mo-icon-tracking")
    assert_html(html, "a.stateful-link svg.mo-icon-check.active-icon")
    assert_html(html, "a span.sr-only", text: "Subscribe")
    assert_html(html, "a span.sr-only.active-label", text: "Subscribed")
    assert_html(html, "a[data-active-title='Subscribed']")
  end

  def test_icon_without_active_pair_omits_stateful_link_class
    html = render_link(name: "View", target: @path, icon: :edit)

    assert_no_html(html, "a.stateful-link")
  end

  # ---- button_to: / confirm: ---------------------------------------------

  def test_button_to_renders_form_with_button
    html = render_link(name: "Delete", target: @path, icon: :delete,
                       button_to: true)

    assert_html(html, "form[action='#{@path}'] button")
    assert_html(html, "form button svg.mo-icon-delete")
  end

  def test_confirm_wires_turbo_confirm_data_attr_on_link
    html = render_link(name: "Delete", target: @path, confirm: "Sure?")

    assert_html(html, "a[data-turbo-confirm='Sure?']")
  end

  def test_params_forwarded_as_hidden_fields_when_button_to
    html = render_link(name: "Delete", target: @path, button_to: true,
                       params: { type: "Observation" })

    assert_html(html,
                "form input[type='hidden'][name='type'][value='Observation']")
  end

  def test_params_dropped_for_plain_anchor
    html = render_link(name: "View", target: @path,
                       params: { type: "Observation" })

    assert_no_html(html, "input[name='type']")
    assert_no_html(html, "a[params]")
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

  def render_tab_link(**)
    render(Components::Link::Get.new(**))
  end
end
