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

  def test_collapse_classes_class_method_matches_instance_rendering
    assert_equal("collapse", Components::CollapseDiv.collapse_classes)
    assert_equal("collapse in",
                 Components::CollapseDiv.collapse_classes(expanded: true))
    assert_equal("collapse panel-collapse",
                 Components::CollapseDiv.collapse_classes(panel: true))
    assert_equal("collapse in panel-collapse no-transition",
                 Components::CollapseDiv.collapse_classes(
                   expanded: true, panel: true, html_class: "no-transition"
                 ))
  end

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

  def test_attributes_class_and_id_ignored
    html = render(Components::CollapseDiv.new(
                    id: "real",
                    attributes: { id: "override", class: "override",
                                  data: { foo: "bar" } }
                  ))

    assert_html(html, "div.collapse#real[data-foo='bar']")
    assert_no_html(html, "#override")
  end

  def test_element_kwarg_renders_alternate_tag
    html = render(Components::CollapseDiv.new(id: "foo", element: :tbody))

    assert_html(html, "tbody.collapse#foo")
    assert_no_html(html, "div.collapse")
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
        render(::Components::Help.new(well: true)) { plain("help text") }
      end
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(id: help_id)) do
        render(::Components::Help.new(well: true)) { plain("help text") }
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

  # Views::Layouts::TopNav search-nav row ------------------------

  def test_top_nav_search_nav_row_parity
    data_attrs = {
      controller: "search-type",
      search_type_help_types_value: [:names, :observations].to_json,
      search_type_form_types_value: [:names, :observations].to_json
    }

    old_html = render(phlex_wrapper do
      div(class: "collapse w-100", id: "search_nav",
          data: data_attrs) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "search_nav", html_class: "w-100",
               attributes: { data: data_attrs }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#search_nav", label: "top_nav_search_nav_row"
    )
  end

  # Views::Layouts::TopNav search-nav toggle button ---------------
  #
  # Not a byte-diff parity test: adopting Button::CollapseToggle adds
  # a `.collapsed` class the old hand-rolled markup never had (its
  # `collapsed:` prop defaults to true, correctly reflecting that
  # #search_nav starts closed). Verified harmless -- the only CSS
  # rules keying off `.collapsed` are scoped to `.icon-link`/
  # `.panel-collapse-trigger` or to descendant `.collapse-toggle-*`
  # spans (mo/_icons.scss, mo/_form_elements.scss), neither of which
  # this button has. So this asserts every attribute the old markup
  # had is preserved, and documents the one accepted addition.

  def test_top_nav_search_nav_toggle_parity
    html = render(phlex_wrapper do
      render(::Components::Button.new(
               type: :collapse_toggle,
               target_id: "search_nav",
               variant: :outline, size: :sm,
               class: "top_nav_button",
               aria: { expanded: "false", controls: "search_nav" }
             )) { render(::Components::Icon.new(type: :search, title: "Search")) }
    end)

    assert_html(html, "button.btn.btn-outline-default.btn-sm.top_nav_button" \
                       "[data-toggle='collapse'][data-target='#search_nav']" \
                       "[aria-expanded='false'][aria-controls='search_nav']")
    # Accepted, verified-harmless addition from Button::CollapseToggle.
    assert_html(html, "button.collapsed")
  end

  # Views::Layouts::TopNav::SearchBar collapse targets -------------

  def test_search_bar_elements_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse in w-100", id: "search_bar_elements",
          data: { search_type_target: "bar",
                  action: "$shown.bs.collapse->search-type#closeForm" }) do
        plain("content")
      end
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "search_bar_elements", expanded: true, html_class: "w-100",
               attributes: {
                 data: { search_type_target: "bar",
                         action:
                           "$shown.bs.collapse->search-type#closeForm" }
               }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#search_bar_elements", label: "search_bar_elements"
    )
  end

  def test_search_bar_help_target_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse w-100", id: "search_bar_help",
          data: { search_type_target: "help" })
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "search_bar_help", html_class: "w-100",
               attributes: { data: { search_type_target: "help" } }
             ))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#search_bar_help", label: "search_bar_help"
    )
  end

  def test_search_nav_form_target_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse w-100 border-top", id: "search_nav_form",
          data: { search_type_target: "form",
                  action: "$shown.bs.collapse->search-type#closeBar" })
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "search_nav_form", html_class: "w-100 border-top",
               attributes: {
                 data: { search_type_target: "form",
                         action: "$shown.bs.collapse->search-type#closeBar" }
               }
             ))
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#search_nav_form", label: "search_nav_form"
    )
  end

  # Header::IndexBar::FilterCaption collapse targets ---------------

  def test_filter_caption_truncated_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse in", id: "caption-truncated",
          data: { filter_caption_target: "truncated" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "caption-truncated", expanded: true,
               attributes: { data: { filter_caption_target: "truncated" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#caption-truncated", label: "filter_caption_truncated"
    )
  end

  def test_filter_caption_full_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse", id: "caption-full",
          data: { filter_caption_target: "full" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "caption-full",
               attributes: { data: { filter_caption_target: "full" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#caption-full", label: "filter_caption_full"
    )
  end

  # Projects::Aliases::Form panel targets (no id -- Stimulus type-switch
  # keys off data-type-switch-type, not a collapse-trigger id) --------

  def test_aliases_form_user_panel_expanded_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse in",
          data: { type_switch_target: "panel", type_switch_type: "user" }) do
        plain("content")
      end
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               expanded: true,
               attributes: {
                 data: { type_switch_target: "panel",
                         type_switch_type: "user" }
               }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "[data-type-switch-type='user']",
      label: "aliases_form_user_panel"
    )
  end

  def test_aliases_form_location_panel_collapsed_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse",
          data: { type_switch_target: "panel",
                  type_switch_type: "location" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               attributes: {
                 data: { type_switch_target: "panel",
                         type_switch_type: "location" }
               }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "[data-type-switch-type='location']",
      label: "aliases_form_location_panel"
    )
  end

  # InatImports::Form panel targets (same no-id type-switch shape) ---

  def test_inat_imports_form_ids_panel_expanded_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse in",
          data: { type_switch_target: "panel", type_switch_type: "ids" }) do
        plain("content")
      end
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               expanded: true,
               attributes: {
                 data: { type_switch_target: "panel", type_switch_type: "ids" }
               }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "[data-type-switch-type='ids']",
      label: "inat_imports_form_ids_panel"
    )
  end

  def test_inat_imports_form_url_panel_collapsed_parity
    old_html = render(phlex_wrapper do
      div(class: "collapse",
          data: { type_switch_target: "panel",
                  type_switch_type: "url" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               attributes: {
                 data: { type_switch_target: "panel", type_switch_type: "url" }
               }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "[data-type-switch-type='url']",
      label: "inat_imports_form_url_panel"
    )
  end

  # Observations::Form::Specimen #specimen_fields target -----------

  def test_specimen_fields_expanded_parity
    old_html = render(phlex_wrapper do
      div(id: "specimen_fields", class: "collapse in") { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "specimen_fields", expanded: true
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#specimen_fields", label: "specimen_fields_expanded"
    )
  end

  def test_specimen_fields_collapsed_parity
    old_html = render(phlex_wrapper do
      div(id: "specimen_fields", class: "collapse") { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(id: "specimen_fields")) do
        plain("content")
      end
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#specimen_fields", label: "specimen_fields_collapsed"
    )
  end

  # Observations::Namings::ReasonsFields #naming_reasons_N_notes target
  # (highest-risk site: live, interactive naming-reasons UI) ---------

  def test_reasons_fields_notes_expanded_parity
    old_html = render(phlex_wrapper do
      div(id: "naming_reasons_1_notes",
          class: class_names("form-group mb-3", "collapse in"),
          data: { naming_reason_target: "collapse" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "naming_reasons_1_notes", expanded: true,
               html_class: "form-group mb-3",
               attributes: { data: { naming_reason_target: "collapse" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#naming_reasons_1_notes", label: "reasons_fields_expanded"
    )
  end

  def test_reasons_fields_notes_collapsed_parity
    old_html = render(phlex_wrapper do
      div(id: "naming_reasons_2_notes",
          class: class_names("form-group mb-3", "collapse"),
          data: { naming_reason_target: "collapse" }) { plain("content") }
    end)
    new_html = render(phlex_wrapper do
      render(::Components::CollapseDiv.new(
               id: "naming_reasons_2_notes",
               html_class: "form-group mb-3",
               attributes: { data: { naming_reason_target: "collapse" } }
             )) { plain("content") }
    end)

    assert_html_element_equivalent(
      wrap(old_html), wrap(new_html),
      selector: "#naming_reasons_2_notes", label: "reasons_fields_collapsed"
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
end
