# frozen_string_literal: true

# Filter form for the identify-observations index. Renders a navbar
# search form with a swappable autocompleter (clade/region) for
# filtering observations that need identification. Rendered by
# `Observations::IdentifyController` via its `_form_identify_filter`
# partial.
#
# Uses dual Stimulus autocompleter targets (clade + region) on all
# elements so the swap mechanism can find them regardless of which
# controller is active.
module Views::Controllers::Observations::Identify
  class Form < ::Components::ApplicationForm
    def initialize(model, **)
      # Preserve the existing `identify_filter` DOM id (Stimulus hooks
      # in the navbar search depend on it) rather than letting the
      # auto-deriver produce `observation_identify_form`.
      super(model, id: "identify_filter", **)
    end

    def view_template
      super do
        render_autocompleter_wrap
        render_type_select_group
        submit(:SEARCH.l, style: :outline_default, class: "px-2")
        submit(:CLEAR.l, style: :outline_default, class: "px-2")
      end
    end

    def form_action
      identify_observations_path
    end

    private

    def form_tag(&block)
      form(action: form_action, method: :get,
           **form_attributes, &block)
    end

    def form_attributes
      {
        id: @attributes[:id],
        # Match the top-nav search bar layout: flexbox row with `gap-2`
        # between items, no padding on the form so it sits flush in
        # its `#search_nav` container.
        class: "navbar-flex flex-grow-1 navbar-form px-0 gap-2",
        data: { controller: initial_controller,
                type: selected }
      }
    end

    # GET forms don't need authenticity tokens or _method fields
    def authenticity_token_field; end
    def _method_field; end

    def selected
      model.type.to_sym
    end

    def initial_controller
      "autocompleter--#{selected}"
    end

    # --- Autocompleter section ---

    # Term input lives inside a `d-flex flex-grow-1` form-group so it
    # expands to fill the row; the type select and submit buttons keep
    # their natural width.
    def render_autocompleter_wrap
      div(class: "form-group has-feedback has-search d-flex " \
                 "flex-grow-1 mb-0 dropdown",
          data: dual_target("wrap")) do
        render_search_icon
        render_hidden_field
        render_term_field
        render_dropdown
      end
    end

    def render_search_icon
      span(class:
        "glyphicon glyphicon-search form-control-feedback")
    end

    def render_hidden_field
      hidden_field(:term_id, data: dual_target("hidden"))
    end

    def render_term_field
      text_field(:term, label: false,
                        placeholder: :filter_by.l,
                        class: "flex-grow-1",
                        autocomplete: "one-time-code",
                        data: dual_target("input"))
    end

    def render_dropdown
      div(class: "auto_complete dropdown-menu",
          data: dual_target("pulldown").merge(
            action: scroll_actions
          )) do
        ul(class: "virtual_list",
           data: dual_target("list")) do
          10.times { |i| render_dropdown_item(i) }
        end
      end
    end

    def render_dropdown_item(index)
      li(class: "dropdown-item") do
        a(href: "#", data: {
            row: index, action: click_actions
          })
      end
    end

    # --- Type select (in form-group to align in the navbar flex row) ---

    def render_type_select_group
      div(class: "form-group text-nowrap mb-0") { render_type_select }
    end

    def render_type_select
      select_field(:type, type_options, label: false,
                                        data: dual_target("select").merge(
                                          action: "autocompleter--clade#swap " \
                                                  "autocompleter--region#swap"
                                        ))
    end

    def type_options
      [[:CLADE.l, :clade], [:REGION.l, :region]]
    end

    # --- Dual-target helpers ---

    def dual_target(target_name)
      {
        autocompleter__clade_target: target_name,
        autocompleter__region_target: target_name
      }
    end

    def scroll_actions
      "scroll->autocompleter--clade#scrollList:passive " \
        "scroll->autocompleter--region#scrollList:passive"
    end

    def click_actions
      "click->autocompleter--clade#selectRow:prevent " \
        "click->autocompleter--region#selectRow:prevent"
    end
  end
end
