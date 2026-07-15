# frozen_string_literal: true

module Views::Controllers::SpeciesLists::WriteIn
  # Phlex form for the "write-in species names" workflow under a
  # species list.
  #
  # The species_list model is passed for the action-URL derivation
  # (`form_action` -> `write_in_species_list_path(@species_list)`).
  # No visible fields are bound to the model — every field is
  # transient operation state under a non-model namespace:
  #
  # - `list[members]`: the textarea of newline-separated names
  # - `member[value]` / `member[notes][<key>]` / `member[lat|lng|alt]` /
  #   `member[is_collection_location]` / `member[specimen]`:
  #   per-observation defaults applied to the obs constructed from
  #   the typed names
  # - `place_name`: top-level WHERE for the observations
  # - `approved_names` / `approved_deprecated_names`: top-level
  #   hidden re-submissions of name-confirmation state, only emitted
  #   when those collections are non-empty
  #
  # Field names go through the helpers in String form (`"member[lat]"`)
  # so the raw `name=` attribute lands as-is on the rendered input,
  # without Superform attempting to bind to a model attribute that
  # doesn't exist. The `value:` option carries the explicit value.
  class Form < ::Components::ApplicationForm
    register_value_helper :strip_tags

    def initialize(species_list, user:, button:, **state)
      @user = user
      @button = button
      extract_state(state)
      super(species_list,
            id: "species_list_write_in_form",
            method: :post)
    end

    # State keyword args — defaults are merged in once and assigned
    # by name. Each key in `STATE_DEFAULTS` becomes an instance
    # variable on the form. Keeps the per-method ABC size manageable
    # (14 ivars otherwise busts `Metrics/AbcSize`).
    STATE_DEFAULTS = {
      new_names: [], deprecated_names: [], multiple_names: nil,
      dubious_where_reasons: [], list_members: nil, place_name: nil,
      member_vote: nil, member_notes: {}, member_notes_parts: [],
      member_lat: nil, member_lng: nil, member_alt: nil,
      member_is_collection_location: nil, member_specimen: nil
    }.freeze

    def extract_state(state)
      STATE_DEFAULTS.merge(state).each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end
    end

    def form_action
      write_in_species_list_path(id: model.id)
    end

    def view_template
      super do
        submit(@button.l, center: true)
        render(ListFeedback.new(
                 new_names: @new_names,
                 deprecated_names: @deprecated_names,
                 multiple_names: @multiple_names
               ))
        render_approval_hiddens
        render_list_members_field
        render(Components::Form::LocationFeedback.new(
                 dubious_where_reasons: @dubious_where_reasons,
                 button: @button
               ))
        render_place_name_field
        render_member_fields_section
        submit(@button.l, center: true)
      end
    end

    private

    def render_approval_hiddens
      if @new_names.present?
        hidden_field("approved_names",
                     value: @new_names.join("\n"))
      end
      return if @deprecated_names.blank?

      hidden_field("approved_deprecated_names",
                   value: @deprecated_names.map(&:id).join(" "))
    end

    def render_list_members_field
      div(class: "form-group mt-3") do
        autocompleter_field("list[members]",
                            type: :name,
                            textarea: true,
                            rows: 8,
                            value: @list_members,
                            label: :form_species_lists_write_in_species)
      end
    end

    def render_place_name_field
      # `:place_name` is a real `SpeciesList` attribute, but its getter
      # is viewer-aware (takes an explicit user) - Superform's Symbol
      # path would call it with no args, so pass `value:` explicitly
      # to get `current_user`'s postal/scientific preference.
      autocompleter_field(:place_name,
                          type: :location,
                          value: model.place_name(current_user),
                          label: :WHERE)
    end

    def render_member_fields_section
      render_vote_field
      render_notes_block
      render_coord_fields
      Help(
        content: :form_observations_lat_long_help.t
      )
      render_is_collection_location_checkbox
      Help(
        content: :form_observations_is_collection_location_help.t
      )
      render_specimen_checkbox
      Help(
        content: :form_observations_specimen_available_help.t
      )
    end

    def render_vote_field
      select_field("member[value]",
                   Vote.confidence_menu,
                   value: @member_vote,
                   label: :form_species_lists_confidence,
                   inline: true)
    end

    def render_notes_block
      div(class: "form-group") do
        label(for: "member_notes") do
          plain("#{:form_species_lists_member_notes.t}:")
        end
        whitespace
        plain("(")
        trusted_html(:general_textile_link.t)
        plain(")")
        br
        @member_notes_parts.each { |part| render_note_part(part) }
      end
    end

    def render_note_part(part)
      key = model.notes_normalized_key(part)
      textarea_field("member[notes][#{key}]",
                     value: @member_notes[part.to_sym],
                     rows: 1,
                     class: "form-control mb-3",
                     label: strip_tags(part.tl))
    end

    def render_coord_fields
      div(class: "form-group form-inline") do
        render_coord_field(:lat, @member_lat, :LATITUDE, 8)
        render_coord_field(:lng, @member_lng, :LONGITUDE, 8)
        render_coord_field(:alt, @member_alt, :ALTITUDE, 6)
      end
    end

    def render_coord_field(field, value, label_text, size)
      text_field("member[#{field}]",
                 value: value,
                 size: size,
                 label: label_text,
                 inline: true)
    end

    def render_is_collection_location_checkbox
      checkbox_field("member[is_collection_location]",
                     value: "1",
                     checked: @member_is_collection_location,
                     label: :form_observations_is_collection_location)
    end

    def render_specimen_checkbox
      checkbox_field("member[specimen]",
                     value: "1",
                     checked: @member_specimen,
                     label: :form_observations_specimen_available)
    end
  end
end
