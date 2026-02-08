# frozen_string_literal: true

# Displays feedback for species list name fields when:
# - Names are not recognized (missing)
# - Names are deprecated (with valid synonyms)
# - Names are ambiguous (multiple matches)
#
# @param new_names [Array<String>, nil] unrecognized name strings
# @param deprecated_names [Array<Name>, nil] deprecated Name objects
# @param multiple_names [Array<Array>, Hash, nil] ambiguous names
#   Array: [[name, other_authors], ...] or Hash: {name => other_authors}
class Components::FormListFeedback < Components::Base
  include Phlex::Rails::Helpers::FieldsFor

  register_output_helper :radio_with_label

  prop :new_names, _Nilable(Array), default: nil
  prop :deprecated_names, _Nilable(Array), default: nil
  prop :multiple_names, _Nilable(_Union(Array, Hash)), default: nil

  def view_template
    render_missing_names if @new_names&.any?
    render_deprecated_names if @deprecated_names&.any?
    render_multiple_names if @multiple_names&.any?
  end

  private

  def render_missing_names
    render(Components::Alert.new(level: :danger, id: "missing_names")) do
      div(class: "font-weight-bold") { :form_list_feedback_missing_names.t }
      div(class: "help-note mr-3") { :form_list_feedback_missing_names_help.t }
      p do
        @new_names.each do |name|
          br
          whitespace
          plain(name)
        end
      end
    end
  end

  def render_deprecated_names
    render(Components::Alert.new(level: :warning, id: "deprecated_names")) do
      div(class: "font-weight-bold") { :form_species_lists_deprecated.t }
      div(class: "help-note mr-3") do
        :form_species_lists_deprecated_help.t
      end
      p do
        @deprecated_names.each do |name|
          render_deprecated_name_choice(name)
        end
      end
    end
  end

  def render_deprecated_name_choice(name)
    approved_names = name.approved_synonyms
    div { trusted_html(name.display_name.t) }

    return unless approved_names.any?

    fields_for(:chosen_approved_names) do |f_c|
      approved_names.each do |other_name|
        radio_with_label(
          form: f_c,
          field: name.id,
          value: other_name.id,
          class: "my-1 mr-4 d-inline-block",
          label: other_name.display_name.t
        )
      end
    end
  end

  def render_multiple_names
    render(Components::Alert.new(level: :warning, id: "ambiguous_names")) do
      div(class: "font-weight-bold") do
        :form_species_lists_multiple_names.t
      end
      div(class: "help-note mr-3") do
        :form_species_lists_multiple_names_help.t
      end
      p do
        @multiple_names.each do |name, other_authors|
          render_multiple_name_choice(name, other_authors)
        end
      end
    end
  end

  def render_multiple_name_choice(name, other_authors)
    div { trusted_html(name.display_name.t) }
    fields_for(:chosen_multiple_names) do |f_c|
      other_authors.each do |other_name|
        radio_with_label(
          form: f_c,
          field: name.id,
          value: other_name.id,
          class: "my-1 mr-4 d-inline-block",
          label: other_name.display_name.t
        )
        plain(" (#{other_name.observations.count})")
        br
      end
    end
  end
end
