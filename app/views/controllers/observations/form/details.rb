# frozen_string_literal: true

# Details section of the observation form: date, location
# autocomplete, lat/lng/alt, related checkboxes, and an embedded
# map. Sub-component of `Views::Controllers::Observations::Form`.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param mode [Symbol] :create or :update
# @param button_name [String] the submit button text
# @param location [Location] optional associated location
# @param default_place_name [String] default place name value
# @param dubious_where_reasons [Array] location feedback reasons
class Views::Controllers::Observations::Form::Details < Views::Base
  prop :form, ::Components::ApplicationForm
  prop :observation, Observation
  prop :mode, _Nilable(_Union(:create, :update)), default: :create
  prop :button_name, String
  prop :location, _Nilable(Location), default: nil
  prop :default_place_name, _Nilable(String), default: nil
  prop :dubious_where_reasons, _Nilable(_Array(String)), default: nil

  def view_template
    Row do
      Column(xs: 12, md: 6) { render_left_column }
      Column(xs: 12, md: 6) { render_map }
    end
  end

  private

  def render_left_column
    render_date_field
    render_collector_field
    div(id: "observation_where") do
      render_location_feedback
      render_location_autocompleter
      render_bounds_hidden_fields
      render_is_collection_location
      render_geolocation_section
      render_log_change if update?
    end
  end

  def render_date_field
    @form.date_field(:when, label: :when.ti, wrap_class: "mb-3")
  end

  # User autocompleter: selecting a suggestion fills the visible field
  # with the user's unique_text_name and the hidden collector_user_id with
  # their id (linking the collector). Free text is still accepted for a
  # collector who is not an MO user; "_user <login>_" markup typed by hand
  # is resolved on save. See #4211 / PR #4452.
  def render_collector_field
    render(@form.field(:collector).autocompleter(
             type: :user,
             wrapper_options: {
               label: :collector.ti,
               wrap_class: "mb-3",
               help: :form_observations_collector_help.t,
               help_collapse: true
             },
             value: @observation.collector,
             hidden_name: :collector_user_id,
             hidden_value: @observation.collector_user_id
           ))
  end

  def render_location_feedback
    return unless @dubious_where_reasons&.any?

    render(Components::Form::LocationFeedback.new(
             dubious_where_reasons: @dubious_where_reasons,
             button: @button_name
           ))
  end

  def render_location_autocompleter
    render(@form.field(:place_name).autocompleter(
             type: :location,
             wrapper_options: { label: location_label },
             value: @default_place_name || @location&.name,
             hidden_name: :location_id,
             hidden_value: @location&.id,
             hidden_data: location_hidden_data,
             create_text: :form_observations_create_locality.l,
             keep_text: :form_observations_use_locality.l,
             edit_text: :form_observations_edit_locality.l,
             map_outlet: "#observation_form",
             controller_id: "observation_location_autocompleter",
             data: { map_target: "placeInput", action: exif_action }
           )) do |field|
      field.with_help do
        render(::Views::Controllers::Observations::Form::LocationHelp.new)
      end
    end
  end

  # Label with multiple span variants for different autocompleter states
  def location_label
    capture do
      span(class: "unconstrained-label") { "#{:where.ti}:" }
      whitespace
      span(class: "constrained-label") do
        "#{:form_observations_locality_contains.l}:"
      end
      whitespace
      span(class: "create-label") { "#{:form_observations_create_locality.l}:" }
    end
  end

  def location_hidden_data
    { map_target: "locationId" }.merge(location_bounds_data).compact_blank
  end

  def location_bounds_data
    return {} unless @location

    {
      north: @location.north&.to_s,
      south: @location.south&.to_s,
      east: @location.east&.to_s,
      west: @location.west&.to_s
    }
  end

  def exif_action
    "form-exif:pointChanged@window->autocompleter--location#swap"
  end

  def render_bounds_hidden_fields
    render(Components::Form::BoundsHiddenFields.new(
             location: @location, target_controller: :map
           ))
  end

  def render_is_collection_location
    @form.checkbox_field(
      :is_collection_location,
      label: :form_observations_is_collection_location,
      wrap_class: "ml-5 mb-5",
      help: :form_observations_is_collection_location_help.t,
      help_collapse: true
    )
  end

  def render_geolocation_section
    render_geolocation_toggle
    render_geolocation_fields
  end

  def render_geolocation_toggle
    render(Components::Form::CheckboxCollapse.new(
             form: @form,
             field: :has_geolocation,
             target_id: "observation_geolocation",
             label: :geolocation.ti,
             expanded: @observation.lat.present?,
             attributes: {
               help: :form_observations_lat_long_help.t,
               help_collapse: true,
               data: { form_exif_target: "collapseCheck" }
             }
           ))
  end

  def render_geolocation_fields
    Collapsible(
      id: "observation_geolocation",
      expanded: @observation.lat.present?,
      data: { form_exif_target: "collapseFields" }
    ) do
      p { :form_observations_click_point.l }
      render_lat_lng_alt_row
      render_gps_hidden_checkbox
    end
  end

  def render_lat_lng_alt_row
    Row(class: "no-gutters", id: "observation_lat_lng_alt") do
      render_coordinate_field(:lat, :lat, :latitude, "º")
      render_coordinate_field(:lng, :lng, :longitude, "º")
      render_coordinate_field(:alt, :alt, :altitude, "m")
    end
  end

  def render_coordinate_field(field, abbr_key, full_key, addon)
    Column(xs: 4) do
      label_html = coordinate_label(abbr_key, full_key)
      @form.text_field(
        field,
        label: label_html,
        wrap_class: "mb-0",
        addon: addon,
        data: {
          map_target: "#{field}Input",
          action: "map#bufferInputs"
        }
      )
    end
  end

  # Label with responsive show/hide variants
  def coordinate_label(abbr_key, full_key)
    capture do
      span(class: "d-none d-sm-inline") { "#{full_key.ti}:" }
      span(class: "d-inline d-sm-none") { "#{abbr_key.ti}:" }
    end
  end

  def render_gps_hidden_checkbox
    @form.checkbox_field(
      :gps_hidden,
      label: :form_observations_gps_hidden,
      wrap_class: "ml-5 mb-5"
    )
  end

  def render_log_change
    @form.checkbox_field(
      :log_change,
      label: :form_observations_log_change,
      checked: true
    )
  end

  def render_map
    render(Components::Form::LocationMap.new(
             id: "observation_form_map", map_type: "observation"
           ))
  end

  # --- Helpers ---

  def update?
    @mode == :update
  end
end
