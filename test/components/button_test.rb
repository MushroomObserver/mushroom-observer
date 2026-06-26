# frozen_string_literal: true

require("test_helper")

class ButtonTest < ComponentTestCase
  def test_default_styling
    html = render_button(name: "Click me")

    assert_html(html, "button[type='button']", text: "Click me")
    assert_html(html, "button.btn.btn-default")
  end

  def test_custom_variant
    html = render_button(name: "Danger", variant: :danger)

    assert_html(html, "button.btn.btn-danger")
  end

  def test_strip_variant_drops_frame
    html = render_button(name: "Bare", variant: :strip, class: "p-0")

    assert_no_html(html, "button.btn")
  end

  def test_extra_class_merged
    html = render_button(name: "Sized", size: :sm)

    assert_html(html, "button.btn.btn-default.btn-sm")
  end

  def test_icon_only_with_sr_only_name
    html = render_button(name: "Remove", icon: :x, variant: :strip,
                         class: "p-0")

    assert_html(html, "button span.sr-only", text: "Remove")
    assert_html(html, "button span.glyphicon")
  end

  def test_raises_on_btn_class_in_class_kwarg
    assert_raises(ArgumentError) do
      render_button(name: "Bad", class: "btn btn-primary")
    end
  end

  def test_data_attrs_pass_through
    html = render_button(name: "Open",
                         data: { action: "confirm-modal#open",
                                 confirm_modal_target: "trigger" })

    assert_html(html, "button[data-action='confirm-modal#open']" \
                      "[data-confirm-modal-target='trigger']")
  end

  def test_id_passes_through
    html = render_button(name: "Labeled", id: "my_button")

    assert_html(html, "button#my_button")
  end

  def test_tag_a_renders_link
    html = render_button(name: "Go", tag: :a, href: "/path", variant: :primary)

    assert_html(html, "a.btn.btn-primary[href='/path']", text: "Go")
    assert_no_html(html, "button")
  end

  def test_block_content_renders_inside_button
    html = render(ButtonWithBlock.new)

    assert_html(html, "button span.block-sentinel", text: "from block")
  end

  private

  # Wrapper so the block executes in a Phlex render context.
  class ButtonWithBlock < Components::Base
    def view_template
      render(Components::Button.new) do
        span(class: "block-sentinel") { plain("from block") }
      end
    end
  end

  def render_button(name:, **)
    render(Components::Button.new(name: name, **))
  end
end

# Tests for the Components::Button::Styling concern's raise paths.
class Components::Button::StylingTest < ComponentTestCase
  def test_unknown_variant_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Button::Styling.btn_class(:nonexistent)
    end
  end

  def test_unknown_size_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Button::Styling.size_class(:jumbo)
    end
  end
end

# Tests for the Components::Button.new dispatcher. Each test verifies
# that the right subclass is invoked by asserting the behavioral HTML
# contract of that subclass, not just the return class.
class Components::ButtonDispatcherTest < ComponentTestCase
  def setup
    super
    @herbarium = herbaria(:nybg_herbarium)
    @project   = projects(:bolete_project)
  end

  def routes
    Rails.application.routes.url_helpers
  end

  # ---- type: :post / :put / :patch / :delete -------------------------

  def test_type_post_emits_post_form_with_submit
    html = render(Components::Button.new(
                    type: :post,
                    name: "Join",
                    target: routes.herbarium_path(id: @herbarium.id)
                  ))

    assert_html(html, "form[method='post']")
    assert_html(html, "button[type='submit']", text: "Join")
    assert_no_html(html, "input[name='_method']")
  end

  def test_type_put_emits_hidden_method_put
    html = render(Components::Button.new(
                    type: :put,
                    name: "Save",
                    target: routes.herbarium_path(id: @herbarium.id)
                  ))

    assert_html(html, "input[name='_method'][value='put']")
    assert_html(html, "button[type='submit']", text: "Save")
  end

  def test_type_patch_emits_hidden_method_patch
    html = render(Components::Button.new(
                    type: :patch,
                    name: "Update",
                    target: routes.herbarium_path(id: @herbarium.id)
                  ))

    assert_html(html, "input[name='_method'][value='patch']")
    assert_html(html, "button[type='submit']", text: "Update")
  end

  def test_type_delete_emits_hidden_method_delete
    html = render(Components::Button.new(
                    type: :delete,
                    target: @herbarium
                  ))

    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, "button[type='submit']")
  end

  # ---- type: :get / :edit / :new / :download -------------------------

  def test_type_get_renders_anchor_to_target
    path = routes.herbarium_path(id: @herbarium.id)
    html = render(Components::Button.new(
                    type: :get, name: "Show", target: path
                  ))

    assert_html(html, "a[href='#{path}']", text: "Show")
    assert_no_html(html, "form")
  end

  def test_type_edit_links_to_edit_path_with_edit_icon
    html = render(Components::Button.new(
                    type: :edit, target: @herbarium
                  ))

    expected = routes.edit_herbarium_path(id: @herbarium.id)
    assert_html(html, "a[href='#{expected}']")
    assert_html(html, "a span.glyphicon")
  end

  def test_type_new_links_to_provided_path_with_add_icon
    path = routes.new_herbarium_path
    html = render(Components::Button.new(
                    type: :new,
                    target: path,
                    name: "New herbarium"
                  ))

    assert_html(html, "a[href='#{path}']", text: "New herbarium")
    assert_html(html, "a span.glyphicon")
  end

  def test_type_download_links_with_download_icon
    path = routes.new_download_species_list_path(
      id: species_lists(:first_species_list).id
    )
    html = render(Components::Button.new(
                    type: :download, target: path
                  ))

    assert_html(html, "a[href='#{path}']")
    assert_html(html, "a span.glyphicon")
  end

  # ---- type: :submit ---------------------------------------------------

  def test_type_submit_renders_button_with_submit_type
    html = render(Components::Button.new(type: :submit, name: "Go"))

    assert_html(html, "button[type='submit']", text: "Go")
    assert_no_html(html, "form")
  end

  def test_type_submit_passes_submits_with_kwarg
    html = render(Components::Button.new(
                    type: :submit,
                    name: "Save",
                    submits_with: "Saving…"
                  ))

    assert_html(html,
                "button[type='submit']" \
                "[data-turbo-submits-with='Saving…']")
  end

  # ---- type: :external -------------------------------------------------

  def test_type_external_opens_in_new_tab_with_noopener
    url = "https://blast.ncbi.nlm.nih.gov"
    html = render(Components::Button.new(
                    type: :external, name: "BLAST", url: url
                  ))

    assert_html(html,
                "a[href='#{url}']" \
                "[target='_blank'][rel='noopener noreferrer']",
                text: "BLAST")
    assert_no_html(html, "form")
  end

  # ---- type: :modal ----------------------------------------------------

  def test_type_modal_wires_stimulus_modal_toggle_controller
    path = routes.trust_modal_project_member_path(
      project_id: @project.id,
      candidate: users(:rolf).id
    )
    html = render(Components::Button.new(
                    type: :modal,
                    name: "Trust settings",
                    target: path,
                    modal_id: "trust_settings"
                  ))

    assert_html(html, "a[href='#{path}']", text: "Trust settings")
    assert_html(html, "a[data-modal='modal_trust_settings']")
    assert_html(html, "a[data-controller='modal-toggle']")
    assert_html(html,
                "a[data-action='modal-toggle#showModal:prevent']")
  end

  # ---- type: :collapse_toggle ------------------------------------------

  def test_type_collapse_toggle_renders_two_state_spans
    html = render(Components::Button.new(
                    type: :collapse_toggle,
                    target_id: "map_div",
                    open_text: "Hide map",
                    closed_text: "Open map",
                    collapsed: true
                  ))

    assert_html(html, "button[type='button'][data-toggle='collapse']" \
                      "[data-target='#map_div']")
    assert_html(html, "button.collapsed")
    assert_html(html, "button span.collapse-toggle-open", text: "Hide map")
    assert_html(html,
                "button span.collapse-toggle-closed", text: "Open map")
  end

  # ---- type: :project --------------------------------------------------

  def test_type_project_dispatches_to_project_with_lg_size
    path = routes.checklist_path(project_id: @project.id)
    html = render(Components::Button.new(
                    type: :project,
                    name: "View checklist",
                    target: path
                  ))

    assert_html(html, "a[href='#{path}']", text: "View checklist")
    assert_html(html, "a.btn-lg")
  end

  # ---- unknown type: raises ArgumentError ------------------------------

  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Button.new(type: :kaboom, name: "X")
    end
  end

  # ---- plain button (no dispatch) --------------------------------------

  def test_no_type_renders_plain_button_element
    html = render(Components::Button.new(
                    name: "Cancel",
                    data: { dismiss: "modal" }
                  ))

    assert_html(html, "button[type='button'][data-dismiss='modal']",
                text: "Cancel")
    assert_no_html(html, "form")
  end

  # ---- variant/size flow through dispatcher ----------------------------

  def test_delete_with_string_target_uses_destroy_label
    html = render(Components::Button.new(type: :delete,
                                         target: "/items/1/delete",
                                         name: nil))

    assert_html(html, "form[action='/items/1/delete']")
    assert_html(html, "button[type='submit']", text: :DESTROY.l)
  end

  def test_variant_passes_through_mutation_dispatch
    html = render(Components::Button.new(
                    type: :delete,
                    target: @herbarium,
                    variant: :danger
                  ))

    assert_html(html, "button[type='submit'].btn-danger")
  end

  def test_size_passes_through_get_dispatch
    path = routes.herbarium_path(id: @herbarium.id)
    html = render(Components::Button.new(
                    type: :get,
                    name: "Show",
                    target: path,
                    size: :sm
                  ))

    assert_html(html, "a.btn-sm[href='#{path}']")
  end

  # ---- block content passes through dispatcher -------------------------

  def test_type_get_block_renders_inside_anchor
    html = render(GetWithBlock.new(
                    path: routes.herbarium_path(id: @herbarium.id)
                  ))

    assert_html(html, "a span.block-sentinel", text: "from block")
    assert_no_html(html, "a span.sr-only")
  end

  class GetWithBlock < Components::Base
    def initialize(path:)
      super()
      @path = path
    end

    def view_template
      render(Components::Button.new(type: :get, name: "Go",
                                    target: @path)) do
        span(class: "block-sentinel") { plain("from block") }
      end
    end
  end
end
