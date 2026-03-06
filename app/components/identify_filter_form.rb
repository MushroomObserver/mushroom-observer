# frozen_string_literal: true

# Phlex component for the identify observations filter form.
# Renders a navbar search form with a swappable autocompleter
# (clade/region) for filtering observations that need identification.
#
# @example Usage in ERB
#   <%= render(Components::IdentifyFilterForm.new(
#         filter_type: params.dig(:filter, :type),
#         filter_term: params.dig(:filter, :term)
#       )) %>
#
class Components::IdentifyFilterForm < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  prop :filter_type, _Nilable(String), default: nil
  prop :filter_term, _Nilable(String), default: nil

  def view_template
    form(**form_attributes) do
      render_autocompleter_wrap
      render_type_select
      render_buttons
    end
  end

  private

  def selected
    @filter_type ? @filter_type.to_sym : :clade
  end

  def value
    @filter_type ? @filter_term : ""
  end

  def initial_controller
    "autocompleter--#{selected}"
  end

  def form_attributes
    {
      action: identify_observations_path,
      method: :get,
      class: "navbar-form navbar-left",
      id: "identify_filter",
      data: { controller: initial_controller, type: selected }
    }
  end

  def render_autocompleter_wrap
    div(**autocompleter_wrap_attributes) do
      render_search_icon
      render_hidden_field
      render_text_field
      render_dropdown
    end
  end

  def autocompleter_wrap_attributes
    {
      class: "form-group has-feedback has-search dropdown",
      data: {
        autocompleter__clade_target: "wrap",
        autocompleter__region_target: "wrap"
      }
    }
  end

  def render_search_icon
    span(class:
      "glyphicon glyphicon-search form-control-feedback")
  end

  def render_hidden_field
    input(
      type: "hidden",
      name: "filter[term_id]",
      value: "",
      data: {
        autocompleter__clade_target: "hidden",
        autocompleter__region_target: "hidden"
      }
    )
  end

  def render_text_field
    input(
      type: "text",
      name: "filter[term]",
      value: value,
      placeholder: :filter_by.l,
      class: "form-control",
      size: 42,
      autocomplete: "one-time-code",
      data: {
        autocompleter__clade_target: "input",
        autocompleter__region_target: "input"
      }
    )
  end

  def render_dropdown
    div(**dropdown_attributes) do
      ul(**list_attributes) do
        10.times { |i| render_dropdown_item(i) }
      end
    end
  end

  def dropdown_attributes
    {
      class: "auto_complete dropdown-menu",
      data: {
        autocompleter__clade_target: "pulldown",
        autocompleter__region_target: "pulldown",
        action: scroll_actions
      }
    }
  end

  def list_attributes
    {
      class: "virtual_list",
      data: {
        autocompleter__clade_target: "list",
        autocompleter__region_target: "list"
      }
    }
  end

  def render_dropdown_item(index)
    li(class: "dropdown-item") do
      a(href: "#", data: {
          row: index, action: click_actions
        })
    end
  end

  def scroll_actions
    [
      "scroll->autocompleter--clade#scrollList:passive",
      "scroll->autocompleter--region#scrollList:passive"
    ].join(" ")
  end

  def click_actions
    [
      "click->autocompleter--clade#selectRow:prevent",
      "click->autocompleter--region#selectRow:prevent"
    ].join(" ")
  end

  def render_type_select
    options = type_options
    select(
      name: "filter[type]",
      class: "form-control",
      data: {
        autocompleter__clade_target: "select",
        autocompleter__region_target: "select",
        action: "autocompleter--clade#swap " \
                "autocompleter--region#swap"
      }
    ) do
      options.each do |label, val|
        if val == selected
          option(value: val, selected: true) { label }
        else
          option(value: val) { label }
        end
      end
    end
  end

  def type_options
    [[:CLADE.l, :clade], [:REGION.l, :region]]
  end

  def render_buttons
    input(type: "submit", value: :SEARCH.l,
          class: "btn btn-default")
    input(type: "submit", value: :CLEAR.l,
          class: "btn btn-default")
  end
end
