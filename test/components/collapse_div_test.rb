# frozen_string_literal: true

require("test_helper")

# Unit tests for Components::CollapseDiv, plus parity tests verifying
# that each converted caller produces identical HTML before and after.
#
# Phlex note: blocks passed to `render(component) { ... }` at the test
# level run in the test's self, so Phlex helpers like `plain` are not
# available. Content that needs Phlex helpers must live inside an
# anonymous Components::Base wrapper — see helpers below.
class CollapseDivTest < ComponentTestCase
  # ---------------------------------------------------------------
  # Unit tests
  # ---------------------------------------------------------------

  def test_closed_by_default
    html = render(Components::CollapseDiv.new(id: "foo"))

    assert_html(html, "div.collapse#foo")
    assert_no_html(html, "div.in")
    assert_no_html(html, "div.panel-collapse")
  end

  def test_expanded_adds_in_class
    html = render(Components::CollapseDiv.new(id: "foo", expanded: true))

    assert_html(html, "div.collapse.in#foo")
  end

  def test_panel_adds_panel_collapse_class
    html = render(Components::CollapseDiv.new(id: "foo", panel: true))

    assert_html(html, "div.collapse.panel-collapse#foo")
    assert_no_html(html, "div.in")
  end

  def test_expanded_panel_with_html_class
    html = render(Components::CollapseDiv.new(
                    id: "foo", expanded: true, panel: true,
                    html_class: "no-transition"
                  ))

    assert_html(html, "div.collapse.in.panel-collapse.no-transition#foo")
  end

  def test_nil_id_omits_id_attr
    html = render(Components::CollapseDiv.new)

    assert_html(html, "div.collapse")
    assert_no_html(html, "div[id]")
  end

  def test_attributes_forwarded
    html = render(Components::CollapseDiv.new(
                    id: "geo",
                    attributes: { data: { form_exif_target: "collapseFields" } }
                  ))

    assert_html(html,
                "div.collapse#geo[data-form-exif-target='collapseFields']")
  end

  def test_yields_content
    html = render(phlex_wrapper do
      render(Components::CollapseDiv.new(id: "foo")) { plain("hello") }
    end)

    assert_html(html, "div.collapse#foo", text: "hello")
  end

  # ---------------------------------------------------------------
  # Parity tests
  # ---------------------------------------------------------------

  # Help::CollapseBlock -----------------------------------------

  def test_collapse_block_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse", id: "cb_1") do
        div(class: "well well-sm mb-3 help-block position-relative") do
          plain("help")
        end
      end
    end)
    new_html = render(phlex_wrapper do
      render(Components::Help::CollapseBlock.new(target_id: "cb_1")) do
        plain("help")
      end
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#cb_1", label: "collapse_block"
    )
  end

  def test_collapse_block_direction_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse", id: "cb_2") do
        div(class: "well well-sm mb-3 help-block position-relative mt-3") do
          plain("help")
          div(class: "arrow-up hidden-xs")
        end
      end
    end)
    new_html = render(phlex_wrapper do
      render(Components::Help::CollapseBlock.new(
               target_id: "cb_2", direction: "up"
             )) { plain("help") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#cb_2", label: "collapse_block_direction"
    )
  end

  # ApplicationForm::FieldWithHelp collapse div -----------------

  def test_field_with_help_collapse_div_parity
    help_id = "my_field_help"

    old_html = render(phlex_wrapper do
      div(class: "collapse", id: help_id) do
        render(::Components::Help::Block.new(well: true)) { plain("help text") }
      end
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(id: help_id)) do
        render(::Components::Help::Block.new(well: true)) { plain("help text") }
      end
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "##{help_id}", label: "field_with_help"
    )
  end

  # Form::TableAccordion ----------------------------------------
  # Parity at the div level — slot machinery is tested separately.

  def test_table_accordion_view_pane_parity
    old_html = render(phlex_wrapper do
      div(class: "panel-collapse collapse in no-transition", id: "view_acc")
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "view_acc", expanded: true, panel: true,
               html_class: "no-transition"
             ))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#view_acc", label: "accordion_view"
    )
  end

  def test_table_accordion_edit_pane_parity
    old_html = render(phlex_wrapper do
      div(class: "panel-collapse collapse no-transition", id: "edit_acc")
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "edit_acc", panel: true, html_class: "no-transition"
             ))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#edit_acc", label: "accordion_edit"
    )
  end

  # Panel collapse body -----------------------------------------
  # Parity at the div level — Panel slot machinery is tested separately.

  def test_panel_collapse_body_closed_parity
    old_html = render(phlex_wrapper do
      div(class: "panel-collapse collapse", id: "pb1")
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(id: "pb1", panel: true))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#pb1", label: "panel_body_closed"
    )
  end

  def test_panel_collapse_body_open_parity
    old_html = render(phlex_wrapper do
      div(class: "panel-collapse collapse in", id: "pb2")
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(id: "pb2", panel: true,
                                           expanded: true))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#pb2", label: "panel_body_open"
    )
  end

  # Form::LocationMap -------------------------------------------

  def test_location_map_collapse_div_parity
    old_html = render(phlex_wrapper do
      div(id: "lm1", class: "form-map collapse",
          data: { map_target: "mapDiv", editable: "true",
                  map_type: "observation", location_format: "postal",
                  indicator_url: asset_path("indicator.gif") })
    end)
    new_html = render(
      Components::Form::LocationMap.new(id: "lm1", map_type: "observation")
    )

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#lm1", label: "location_map"
    )
  end

  # Observations::Form::Details geolocation ---------------------

  def test_details_geolocation_closed_parity
    old_html = render(phlex_wrapper do
      div(id: "observation_geolocation",
          class: "collapse",
          data: { form_exif_target: "collapseFields" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "observation_geolocation",
               attributes: { data: { form_exif_target: "collapseFields" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#observation_geolocation", label: "geolocation_closed"
    )
  end

  def test_details_geolocation_open_parity
    old_html = render(phlex_wrapper do
      div(id: "observation_geolocation",
          class: "collapse in",
          data: { form_exif_target: "collapseFields" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "observation_geolocation",
               expanded: true,
               attributes: { data: { form_exif_target: "collapseFields" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#observation_geolocation", label: "geolocation_open"
    )
  end

  private

  def wrap(html)
    "<div id='parity_root'>#{html}</div>"
  end

  # Returns an anonymous Components::Base instance whose view_template
  # runs the given block in Phlex context (so `plain`, `div`, `render`
  # etc. are all available).
  def phlex_wrapper(&block)
    Class.new(Components::Base) do
      define_method(:view_template, &block)
    end.new
  end

  def render_old_table_accordion(id, view_id, edit_id)
    id_val = id
    view_id_val = view_id
    edit_id_val = edit_id
    old_klass = Class.new(Components::Base) do
      include Phlex::Slotable

      slot :view
      slot :edit
      define_method(:view_template) do
        div(class: "panel-group border-none mb-0", id: id_val) do
          div(class: "panel border-none bg-none") do
            div(class: "panel-collapse collapse in no-transition",
                id: view_id_val) { render(view_slot) if view_slot? }
            div(class: "panel-collapse collapse no-transition",
                id: edit_id_val) { render(edit_slot) if edit_slot? }
          end
        end
      end
    end
    render(old_klass.new) do |a|
      a.with_view { plain("view") }
      a.with_edit { plain("edit") }
    end
  end
end
