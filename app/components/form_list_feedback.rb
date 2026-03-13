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

    options = approved_names.map { |n| [n.id, n.display_name.t] }
    render(name_choice_radio_field(
             "chosen_approved_names", name.id, options
           ))
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
    options = other_authors.map do |n|
      count = n.observations.count
      [n.id, [n.display_name.t, " (#{count})"].safe_join]
    end
    render(name_choice_radio_field(
             "chosen_multiple_names", name.id, options
           ))
  end

  def name_choice_radio_field(namespace, field_id, options)
    proxy = Components::ApplicationForm::FieldProxy.new(
      namespace, field_id
    )
    Components::ApplicationForm::RadioField.new(
      proxy, *options,
      wrapper_options: { wrap_class: "my-1 mr-4 d-inline-block" }
    )
  end
end
