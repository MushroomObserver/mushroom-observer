# frozen_string_literal: true

# Superform component for the identify observations filter form.
# Renders a navbar search form with a swappable autocompleter
# (clade/region) for filtering observations that need identification.
#
# Uses dual Stimulus autocompleter targets (clade + region) on all
# elements so the swap mechanism can find them regardless of which
# controller is active.
#
# @example Usage in ERB
#   <%= render(Components::IdentifyFilterForm.new(
#         FormObject::IdentifyFilter.new(
#           type: params.dig(:filter, :type),
#           term: params.dig(:filter, :term)
#         )
#       )) %>
#
class Components::IdentifyFilterForm < Components::ApplicationForm
  include Phlex::Rails::Helpers::LinkTo

  def initialize(model, **)
    super(model, id: "identify_filter", **)
  end

  def view_template
    render_autocompleter_wrap
    render_type_select
    submit(:SEARCH.l)
    submit(:CLEAR.l)
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
      class: "navbar-form navbar-left",
      data: { controller: initial_controller,
              type: selected }
    }
  end

  # GET forms don't need authenticity tokens or _method fields
  def authenticity_token_field; end
  def _method_field; end

  def selected
    type = model.type
    type.present? ? type.to_sym : :clade
  end

  def initial_controller
    "autocompleter--#{selected}"
  end

  # --- Autocompleter section ---

  def render_autocompleter_wrap
    div(class: "form-group has-feedback has-search dropdown",
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
                      size: 42,
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

  # --- Type select (bare, no form-group wrapper) ---

  def render_type_select
    select(name: "filter[type]", id: "filter_type",
           class: "form-control",
           data: dual_target("select").merge(
             action: "autocompleter--clade#swap " \
                     "autocompleter--region#swap"
           )) do
      type_options.each do |label, val|
        option(value: val, selected: val == selected) { label }
      end
    end
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
