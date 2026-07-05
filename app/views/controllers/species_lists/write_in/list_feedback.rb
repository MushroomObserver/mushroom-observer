# frozen_string_literal: true

module Views::Controllers::SpeciesLists::WriteIn
  # Displays feedback for species list name fields when:
  # - Names are not recognized (missing)
  # - Names are deprecated (with valid synonyms)
  # - Names are ambiguous (multiple matches)
  #
  # Rendered by `species_lists/write_in/_form.rb`.
  #
  # @param new_names [Array<String>, nil] unrecognized name strings
  # @param deprecated_names [Array<Name>, nil] deprecated Name objects
  # @param multiple_names [Array<Array>, Hash, nil] ambiguous names
  #   Array: [[name, other_authors], ...] or Hash: {name => other_authors}
  class ListFeedback < ::Components::Base
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
      Alert(level: :danger, id: "missing_names") do
        div(class: "font-weight-bold") do
          :form_list_feedback_missing_names.t
        end
        Help(
          content: :form_list_feedback_missing_names_help.t
        )
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
      Alert(level: :warning, id: "deprecated_names") do
        div(class: "font-weight-bold") do
          :form_species_lists_deprecated.t
        end
        Help(
          content: :form_species_lists_deprecated_help.t
        )
        p do
          @deprecated_names.each do |name|
            render_deprecated_name_choice(name)
          end
        end
      end
    end

    def render_deprecated_name_choice(name)
      approved_names = name.approved_synonyms
      div { trusted_html(name.user_display_name(current_user).t) }

      return unless approved_names.any?

      options = approved_names.map do |n|
        [n.id, n.user_display_name(current_user).t]
      end
      render(name_choice_radio_field(
               "chosen_approved_names", name.id, options
             ))
    end

    def render_multiple_names
      Alert(level: :warning, id: "ambiguous_names") do
        div(class: "font-weight-bold") do
          :form_species_lists_multiple_names.t
        end
        Help(
          content: :form_species_lists_multiple_names_help.t
        )
        p do
          @multiple_names.each do |name, other_authors|
            render_multiple_name_choice(name, other_authors)
          end
        end
      end
    end

    def render_multiple_name_choice(name, other_authors)
      div { trusted_html(name.user_display_name(current_user).t) }
      options = other_authors.map do |n|
        count = n.observations.count
        [n.id, [n.user_display_name(current_user).t, " (#{count})"].safe_join]
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
end
