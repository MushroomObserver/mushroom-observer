# frozen_string_literal: true

# Form for creating or editing locations.
# Includes an interactive map, compass inputs for coordinates, and
# elevation inputs. Handles locked locations for non-admin users.
#
# @example Usage
#   render(Components::LocationForm.new(
#     @location,
#     display_name: @display_name,
#     original_name: @original_name
#   ))
#
class Components::LocationForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(model, display_name: nil, original_name: nil,
                 set_observation: nil, set_species_list: nil,
                 set_user: nil, set_herbarium: nil,
                 dubious_where_reasons: nil, **)
    @display_name = display_name
    @original_name = original_name
    @set_observation = set_observation
    @set_species_list = set_species_list
    @set_user = set_user
    @set_herbarium = set_herbarium
    @dubious_where_reasons = dubious_where_reasons
    model.force_valid_lat_lngs!
    super(model, id: "location_form", **)
  end
  # rubocop:enable Metrics/ParameterLists

  def around_template
    @attributes[:data] ||= {}
    @attributes[:data][:controller] = "map"
    @attributes[:data][:map_open] = "true"
    super
  end

  def view_template
    if !model.locked || in_admin_mode?
      render_editable_form
    else
      render_locked_form
    end
  end

  private

  def render_editable_form
    render_location_feedback
    div(class: "row") do
      div(class: "col-md-8 col-lg-6") { render_fields }
      div(class: "col-md-4 col-lg-6 mb-3 mt-3") { render_map }
    end
  end

  def render_location_feedback
    return unless @dubious_where_reasons&.any?

    # Set instance variable for the partial and render it
    view_context.instance_variable_set(
      :@dubious_where_reasons, @dubious_where_reasons
    )
    render(partial("controllers/shared/form_location_feedback",
                   button: submit_text))
  end

  def render_fields
    render_display_name_field
    render_coordinate_section
    render_locked_checkbox if in_admin_mode?
    render_notes_field
    render_hidden_checkbox if model.observations.empty?
    submit(submit_text, center: false, class: "mt-4")
  end

  def render_display_name_field
    text_field(:display_name, value: @display_name, label: "#{:WHERE.t}:",
                              data: display_name_data,
                              help: :form_locations_help.t,
                              button: :form_locations_find_on_map.l,
                              button_data: { map_target: "showBoxBtn",
                                             action: "map#showBox" })
  end

  def display_name_data
    { autofocus: true, map_target: "placeInput" }
  end

  def render_coordinate_section
    div(class: "row mt-5") do
      div(class: "col-sm-8") do
        FormCompassFields(form: self, location: model)
      end
      div(class: "col-sm-4") do
        FormElevationFields(form: self, location: model)
      end
    end
  end

  def render_locked_checkbox
    checkbox_field(:locked, label: :form_locations_locked.t, wrap_class: "mt-3")
  end

  def render_notes_field
    notes_help = capture do
      p { :form_locations_notes_help.t }
      p { trusted_html(:shared_textile_help.l) }
    end
    textarea_field(:notes, label: "#{:NOTES.t}:", help: notes_help)
  end

  def render_hidden_checkbox
    checkbox_field(:hidden, label: :form_locations_hidden.t,
                            wrap_class: "mt-3 mr-3",
                            help: :form_locations_hidden_doc.t)
  end

  def render_map
    Map(objects: [model], editable: true, map_type: "location", controller: nil)
  end

  def render_locked_form
    render_locked_display
  end

  def render_locked_display
    div(class: "row") do
      div(class: "col-sm-6 col-md-4 col-lg-3") do
        render_locked_fields
        div(class: "help-block") { :show_location_locked.l }
      end
      div(class: "col-sm-6 col-md-8 col-lg-9 mb-3 mt-3") do
        Map(objects: [model])
      end
    end
  end

  def render_locked_fields
    hidden_field(:display_name, value: @display_name)
    render_locked_field_display(:display_name, model.display_name.t)
    render_locked_coordinate(:north)
    render_locked_coordinate(:south)
    render_locked_coordinate(:east)
    render_locked_coordinate(:west)
    render_locked_elevation if model.high.present? && model.low.present?
  end

  def render_locked_field_display(_field, value)
    div(class: "mb-0") do
      strong { "#{:WHERE.l}:" }
      whitespace
      plain(value)
    end
  end

  def render_locked_coordinate(direction)
    value = model.send(direction)
    hidden_field(direction, value: value.to_s)
    div(class: "mb-0") do
      strong { "#{direction.upcase.to_sym.l}:" }
      whitespace
      plain("#{value}°")
    end
  end

  def render_locked_elevation
    [:high, :low].each do |dir|
      value = model.send(dir)
      hidden_field(dir, value: value.to_s)
      div(class: "mb-0") do
        strong { "#{:"show_location_#{dir}est".l}:" }
        whitespace
        plain("#{value}m")
      end
    end
  end

  def submit_text
    create? ? :CREATE.l : :UPDATE.l
  end

  def create?
    model.new_record?
  end

  def form_action
    if create?
      url_for(
        controller: "locations",
        action: :create,
        where: @original_name,
        approved_where: @display_name,
        set_observation: @set_observation,
        set_species_list: @set_species_list,
        set_user: @set_user,
        set_herbarium: @set_herbarium,
        only_path: true
      )
    else
      url_for(
        controller: "locations",
        action: :update,
        id: model.id,
        approved_where: @display_name,
        only_path: true
      )
    end
  end
end
