# frozen_string_literal: true

# Bootstrap panel + add/search form for list-style show pages
# (project show, species_list show): a name autocompleter to check
# whether a species is already in the list, plus a Field Slip quick-
# add -- both routed through `ListAddDispatchController#new` to add a new
# Observation to the page's object.
#
# The form posts flat top-level params (`name`, `field_slip`,
# `object_id`, `object_type`, `project`) to `ListAddDispatchController`.
# Because the controller expects flat params, every field on this
# form uses a String-keyed `name=` (the supported FieldProxy path),
# not a model-namespaced Symbol. The form has no backing model --
# `nil` is passed for the model arg, the form id is set explicitly so
# `derive_form_id` skips the model-name fallback.
class Components::ListAdd < Components::ApplicationForm
  prop :object, _Union(::Project, ::SpeciesList)
  # These are `Observation` records (joined to `Name`, selecting only
  # `text_name`/`id`) -- see the `object_names` query in
  # ProjectsController/SpeciesListsController#show. Only used here via
  # `.to_json` for the Stimulus autocompleter match list.
  prop :object_names, _Array(::Observation)
  prop :project, _Nilable(::Project), default: nil

  def initialize(**)
    super(FormObject::ListAdd.new, id: "list_add_form", **)
  end

  def form_action
    list_add_dispatch_path
  end

  # Wrap the rendered `<form>` in the panel so the panel sits outside
  # the form tag.
  def around_template(&block)
    Panel(
      panel_id: "list_add", panel_class: "mt-3"
    ) do |panel|
      panel.with_heading { plain(:list_add_heading.l(type: heading_type)) }
      panel.with_body { super(&block) }
    end
  end

  def view_template
    hidden_field("object_id", value: @object.id)
    hidden_field("object_type", value: @object.class.name)
    # Coerce nil to "" so the `value=""` attribute renders even when
    # no project context is set. `ListAddDispatchController` treats nil
    # and "" identically.
    hidden_field("project", value: @project&.id.to_s)
    render_search_status
  end

  private

  def heading_type
    @object.is_a?(::Project) ? :project : :list
  end

  # The search-status UI is a Stimulus-driven block with three pieces:
  # a name autocompleter whose label row carries the colored
  # status-light indicator inline (off / red / green, via the
  # autocompleter's `label_append` slot), and a Field-Slip quick-add
  # input. The status light drives off whether the typed name matches
  # any of `@object_names`.
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
      Row do
        Column(xs: 12, md: 7) { render_name_autocompleter }
        Column(xs: 12, md: 5) { render_field_slip_input }
      end
    end
  end

  def render_name_autocompleter
    # The status light renders into the autocompleter's `label_append`
    # slot, so it shares the label row, after the (space-reserving)
    # has-id checkmark.
    autocompleter_field(
      "name", type: :name, label: :search_status_label.ti,
              wrap_class: "mb-3 mb-md-0",
              data: {
                search_status_target: "input",
                action: [
                  "change->search-status#checkMatch",
                  "keyup->search-status#checkMatch",
                  "focus->search-status#checkMatch"
                ].join(" ")
              }
    ) { |f| f.with_label_append { render_status_light } }
  end

  def render_field_slip_input
    div(class: "field-slip-container field-group") do
      label(for: "field_slip", class: "text-nowrap") do
        append_colon(:field_slip.ti)
      end
      Help(element: :span, content: "(#{:optional.l})", class: "ml-2")
      div(class: "flex-bar") do
        # `label: false` skips the form-group wrapper; the explicit
        # `<label>` above plays that role here.
        text_field("field_slip", label: false,
                                 class: "form-control mr-3", size: 9)
        render_add_submit
      end
    end
  end

  def render_add_submit
    submit("Add")
  end

  def render_status_light
    span(class: "status-indicator ml-3 mr-2",
         data: { search_status_target: "light" })
    span(class: "status-text",
         data: { search_status_target: "message" }) do
      plain(:search_status_all_names.l)
    end
  end

  # Keyed by the three states the Stimulus controller uses for the
  # status-light indicator (off = no input yet, red = no match,
  # green = unique match in `@object_names`).
  def status_messages
    {
      off: :search_status_all_names.l,
      red: :search_status_has_no_name.l,
      green: :search_status_has_name.l
    }
  end
end
