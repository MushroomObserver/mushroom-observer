# frozen_string_literal: true

# Bootstrap panel + search-status form for list-style show pages
# (project show, species_list show).
#
# The form posts to `AddDispatchController#new`, which reads flat
# top-level params (`name`, `field_slip`, `object_id`, `object_type`,
# `project`) and routes to either a new observation or a field-slip
# scan depending on which fields are filled in. Because the controller
# expects flat params, every field on this form uses a String-keyed
# `name=` (the supported FieldProxy path), not a model-namespaced
# Symbol. The form has no real backing model — `nil` is passed for the
# model arg, the form id is set explicitly so `derive_form_id` skips
# the model-name fallback.
class Components::ListGroup::Search < Components::ApplicationForm
  def initialize(object:, object_names:, project: nil, **)
    @object = object
    @object_names = object_names
    @project = project
    super(FormObject::ListSearch.new, id: "list_search_form", **)
  end

  def form_action
    add_dispatch_path
  end

  # Wrap the rendered `<form>` in the list-search panel so the panel
  # sits OUTSIDE the form tag — same shape the ERB partial used.
  def around_template(&block)
    Panel(
      panel_id: "list_search", panel_class: "mt-3"
    ) do |panel|
      panel.with_body { super(&block) }
    end
  end

  def view_template
    hidden_field("object_id", value: @object.id)
    hidden_field("object_type", value: @object.class.name)
    # Coerce nil to "" so the `value=""` attribute renders even when
    # no project context is set — matches Rails' `hidden_field` ERB
    # output. `AddDispatchController` treats nil and "" identically.
    hidden_field("project", value: @project&.id.to_s)
    render_search_status
  end

  private

  # The search-status UI is a Stimulus-driven row with three pieces:
  # a colored status-light indicator (off / red / green), a Field-Slip
  # quick-add input, and a name autocompleter that drives the status
  # light based on whether the typed name matches any of `@object_names`.
  def render_search_status
    # `search-status-{messages,matches}-value` are Stimulus value attrs
    # that the JS controller parses as JSON. Rails serializes Hash /
    # Relation values automatically when assigning to `data-`; Phlex
    # doesn't, so we `to_json` both sides explicitly.
    div(
      class: "search-status",
      data: { controller: "search-status",
              search_status_messages_value: status_messages.to_json,
              search_status_matches_value: @object_names.to_json }
    ) do
      div(class: "d-flex flex-row align-items-center form-inline mb-2") do
        render_status_light
        render_field_slip_input
      end
      render_name_autocompleter
    end
  end

  def render_status_light
    div(class: "status-light-container mb-2 mr-5") do
      span(class: "status-indicator",
           data: { search_status_target: "light" })
      # Initial label is keyed `:name` (the autocompleter field's
      # type), not `object.type_tag`. The Stimulus controller swaps
      # the visible message based on user input using the JSON-encoded
      # `messages_value` below — which IS keyed by `object.type_tag`.
      span(class: "status-text",
           data: { search_status_target: "message" }) do
        plain(:search_status_all_names.l(type: :name))
      end
    end
  end

  def render_field_slip_input
    div(class: "field-slip-container field-group flex-bar") do
      label(for: "field_slip",
            class: "font-weight-normal text-nowrap") do
        plain("Field Slip:")
      end
      # `label: false` skips the form-group wrapper; the outer
      # explicit `<label>` above plays that role here.
      text_field("field_slip", label: false,
                               class: "form-control mx-3", size: 9)
      submit("Add")
    end
  end

  def render_name_autocompleter
    # The ERB partial applied its layout `mb-2` to the autocompleter's
    # form-group wrapper — matched here with `wrap_class:` so the
    # margin sits on `.form-group.dropdown`, not on the `<input>`.
    autocompleter_field(
      "name", type: :name, label: :SEARCH, wrap_class: "mb-2",
              data: {
                search_status_target: "input",
                action: [
                  "change->search-status#checkMatch",
                  "keyup->search-status#checkMatch",
                  "focus->search-status#checkMatch"
                ].join(" ")
              }
    )
  end

  # Keyed by the three states the Stimulus controller uses for the
  # status-light indicator (off = no input yet, red = no match,
  # green = unique match in `@object_names`).
  def status_messages
    type = object_type_tag
    {
      off: :search_status_all_names.l(type: type),
      red: :search_status_has_no_name.l(type: type),
      green: :search_status_has_name.l(type: type)
    }
  end

  def object_type_tag
    @object.type_tag
  end
end
