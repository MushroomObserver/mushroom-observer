# frozen_string_literal: true

# Checkbox-gated lat/lng/alt fields: a `CheckboxCollapse` toggle
# (label "Geolocation") wrapping a `Collapsible` row of 3 text fields
# with degree/meter input-group addons and responsive full/abbreviated
# labels. Shared by the observation form (live-map Stimulus wiring
# layered on via `toggle_data:`/`fields_data:`/`field_data:`) and the
# species-list write-in form (no map, plain fields).
#
# `lat_field:`/`lng_field:`/`alt_field:`/`toggle_field:` accept a
# Symbol (model-bound) or String (raw `name=`, per the field helpers'
# usual Symbol/String paths) -- whatever `form.text_field`/
# `form.checkbox_field` already accept. A String field has no model
# attribute to read, so its current value must come through
# `field_value:` (keyed by :lat/:lng/:alt) -- a Symbol field resolves
# its value from the model as usual and needs no entry there.
#
# `before_fields:` (pre-rendered via `capture`) sits inside the
# `Collapsible`, above the coordinate row -- e.g. a map-click tip. Any
# block passed is rendered below the row -- e.g. a `gps_hidden`
# checkbox.
#
# @example Plain (no map)
#   render(Components::Form::GeolocationFields.new(
#     form: self, toggle_field: "member[has_geolocation]",
#     lat_field: "member[lat]", lng_field: "member[lng]",
#     alt_field: "member[alt]", target_id: "member_geolocation",
#     expanded: @member_lat.present?,
#     field_value: { lat: @member_lat, lng: @member_lng, alt: @member_alt }
#   ))
#
# @example With live-map Stimulus wiring
#   render(Components::Form::GeolocationFields.new(
#     form: @form, toggle_field: :has_geolocation,
#     lat_field: :lat, lng_field: :lng, alt_field: :alt,
#     target_id: "observation_geolocation",
#     expanded: @observation.lat.present?,
#     toggle_data: { map_target: "geolocationCheck",
#                    action: "map#geolocationToggled" },
#     fields_data: { map_target: "geolocationFields" },
#     field_data: { lat: { map_target: "latInput" } },
#     before_fields: capture { p { :form_observations_click_point.l } }
#   )) { render_gps_hidden_checkbox }
class Components::Form::GeolocationFields < Components::Base
  FieldName = _Union(Symbol, String)

  prop :form, ::Components::ApplicationForm
  prop :toggle_field, FieldName
  prop :lat_field, FieldName
  prop :lng_field, FieldName
  prop :alt_field, FieldName
  prop :target_id, String
  prop :expanded, _Boolean, default: false
  prop :toggle_data, _Hash(Symbol, String), default: -> { {} }
  prop :fields_data, _Hash(Symbol, String), default: -> { {} }
  prop :field_data, _Hash(Symbol, _Hash(Symbol, String)), default: -> { {} }
  prop :field_value, _Hash(Symbol, _Nilable(String)), default: -> { {} }
  prop :before_fields, _Nilable(String), default: nil

  def view_template(&block)
    render_toggle
    render_fields(&block)
  end

  private

  def render_toggle
    render(Components::Form::CheckboxCollapse.new(
             form: @form,
             field: @toggle_field,
             target_id: @target_id,
             label: :geolocation.ti,
             expanded: @expanded,
             help: :form_observations_lat_long_help.t,
             help_collapse: true,
             data: @toggle_data
           ))
  end

  def render_fields(&block)
    Collapsible(id: @target_id, expanded: @expanded, data: @fields_data) do
      trusted_html(@before_fields) if @before_fields
      render_coordinate_row
      yield if block
    end
  end

  def render_coordinate_row
    Row(id: "#{@target_id}_lat_lng_alt") do
      render_coordinate_field(@lat_field, :lat, :latitude, "º")
      render_coordinate_field(@lng_field, :lng, :longitude, "º")
      render_coordinate_field(@alt_field, :alt, :altitude, "m")
    end
  end

  def render_coordinate_field(field, abbr_key, full_key, addon)
    Column(xs: 4) do
      @form.text_field(
        field,
        **value_attr(abbr_key),
        label: coordinate_label(abbr_key, full_key),
        label_colon: false,
        wrap_class: "mb-0",
        addon: addon,
        data: @field_data[abbr_key] || {}
      )
    end
  end

  # Only pass `value:` when the caller supplies one (write-in form's
  # String-bound fields). A Symbol-bound field resolves its value from
  # the model; passing `value: nil` here would override that
  # resolution and blank the field.
  def value_attr(abbr_key)
    return {} unless @field_value.key?(abbr_key)

    { value: @field_value[abbr_key] }
  end

  # Label with responsive show/hide variants: full word from sm+,
  # abbreviated on xs (too narrow at the 3-up column width).
  def coordinate_label(abbr_key, full_key)
    capture do
      span(class: "d-none d-sm-inline") { append_colon(full_key.ti) }
      span(class: "d-inline d-sm-none") { append_colon(abbr_key.ti) }
    end
  end
end
