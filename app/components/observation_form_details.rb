# frozen_string_literal: true

# Details section of the observation form.
# Renders date, location autocomplete, lat/lng/alt, and related checkboxes.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param mode [Symbol] :create or :update
# @param button_name [String] the submit button text
# @param location [Location] optional associated location
# @param default_place_name [String] default place name value
# @param dubious_where_reasons [Array] location feedback reasons
#
class Components::ObservationFormDetails < Components::Base
  prop :form, _Any
  prop :observation, Observation
  prop :mode, _Nilable(Symbol), default: :create
  prop :button_name, String
  prop :location, _Nilable(Location), default: nil
  prop :default_place_name, _Nilable(String), default: nil
  prop :dubious_where_reasons, _Nilable(_Array(String)), default: nil

  def view_template
    div(class: "row") do
      div(class: "col-xs-12 col-md-6") { render_left_column }
      div(class: "col-xs-12 col-md-6") { render_map }
    end
  end

  private

  def render_left_column
    render_date_field
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
    @form.date_field(:when, label: "#{:WHEN.l}:", wrap_class: "mb-3")
  end

  def render_location_feedback
    return unless @dubious_where_reasons&.any?

    FormLocationFeedback(
      dubious_where_reasons: @dubious_where_reasons,
      button: @button_name
    )
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
             controller_data: { map_target: "placeInput",
                                action: exif_action }
           )) do |field|
      field.with_help { observation_location_help }
    end
  end

  # Label with multiple span variants for different autocompleter states
  def location_label
    capture do
      span(class: "unconstrained-label") { "#{:WHERE.l}:" }
      whitespace
      span(class: "constrained-label") do
        "#{:form_observations_locality_contains.l}:"
      end
      whitespace
      span(class: "create-label") { "#{:form_observations_create_locality.l}:" }
    end
  end

  def location_hidden_data
    return {} unless @location

    {
      north: @location.north&.to_f,
      south: @location.south&.to_f,
      east: @location.east&.to_f,
      west: @location.west&.to_f
    }
  end

  def exif_action
    "form-exif:pointChanged@window->autocompleter--location#swap"
  end

  def render_bounds_hidden_fields
    BoundsHiddenFields(location: @location, target_controller: :map)
  end

  def render_is_collection_location
    @form.checkbox_field(
      :is_collection_location,
      label: :form_observations_is_collection_location.l,
      wrap_class: "ml-5 mb-5",
      help: :form_observations_is_collection_location_help.t
    )
  end

  def render_geolocation_section
    render_geolocation_toggle
    render_geolocation_fields
  end

  def render_geolocation_toggle
    @form.checkbox_field(
      :has_geolocation,
      label: "#{:GEOLOCATION.l}:",
      help: :form_observations_lat_long_help.t,
      data: geolocation_toggle_data,
      aria: { controls: "observation_geolocation",
              expanded: @observation.lat.present? }
    )
  end

  def geolocation_toggle_data
    {
      toggle: "collapse",
      target: "#observation_geolocation",
      form_exif_target: "collapseCheck"
    }
  end

  def render_geolocation_fields
    div(id: "observation_geolocation",
        class: class_names("collapse", ("in" if @observation.lat)),
        data: { form_exif_target: "collapseFields" }) do
      p { :form_observations_click_point.l }
      render_lat_lng_alt_row
      render_gps_hidden_checkbox
    end
  end

  def render_lat_lng_alt_row
    div(class: "row no-gutters", id: "observation_lat_lng_alt") do
      render_coordinate_field(:lat, :LAT, :LATITUDE, "º")
      render_coordinate_field(:lng, :LNG, :LONGITUDE, "º")
      render_coordinate_field(:alt, :ALT, :ALTITUDE, "m")
    end
  end

  def render_coordinate_field(field, abbr_key, full_key, addon)
    div(class: "col-xs-4") do
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
      span(class: "d-none d-sm-inline") { "#{full_key.l}:" }
      span(class: "d-inline d-sm-none") { "#{abbr_key.l}:" }
    end
  end

  def render_gps_hidden_checkbox
    @form.checkbox_field(
      :gps_hidden,
      label: :form_observations_gps_hidden.l,
      wrap_class: "ml-5 mb-5"
    )
  end

  def render_log_change
    @form.checkbox_field(
      :log_change,
      label: :form_observations_log_change.t,
      checked: true
    )
  end

  def render_map
    FormLocationMap(id: "observation_form_map", map_type: "observation")
  end

  # --- Helpers ---

  def update?
    @mode == :update
  end
end
