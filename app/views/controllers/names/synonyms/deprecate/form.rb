# frozen_string_literal: true

# Form for deprecating a name in favor of another. Rendered by
# `Names::Synonyms::DeprecateController#new`. Creates its own
# FormObject internally from the provided kwargs.
module Views::Controllers::Names::Synonyms::Deprecate
  class Form < ::Components::ApplicationForm
    # rubocop:disable Metrics/ParameterLists
    def initialize(name:, proposed_name: nil, is_misspelling: false,
                   comment: nil, names: [], valid_names: [],
                   suggest_corrections: false, parent_deprecated: nil, **)
      @name = name
      @names = names
      @valid_names = valid_names
      @suggest_corrections = suggest_corrections
      @parent_deprecated = parent_deprecated

      form_object = FormObject::DeprecateSynonym.new(
        proposed_name: proposed_name,
        is_misspelling: is_misspelling,
        comment: comment
      )
      super(form_object, **)
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      submit(:SUBMIT.l, center: true)
      render_name_feedback if model.proposed_name.present?
      render_proposed_field
      render_misspelling_field
      render_comment_field
    end

    def render_proposed_field
      autocompleter_field(:proposed_name,
                          type: :name,
                          label: "#{:name_deprecate_preferred.l}:",
                          inline: true, data: { autofocus: true })
      Help(
        content: :name_deprecate_preferred_help.tp
      )
    end

    def render_misspelling_field
      checkbox_field(:is_misspelling, label: :form_names_misspelling.l)
    end

    def render_comment_field
      textarea_field(:comment, label: "#{:name_deprecate_comments.l}:",
                               cols: 80, rows: 5, inline: true)
      Help(content: deprecate_comments_help)
    end

    private

    def render_name_feedback
      render(Components::Form::NameFeedback.new(
               given_name: model.proposed_name,
               button_name: :SUBMIT.l,
               names: @names,
               valid_names: @valid_names,
               suggest_corrections: @suggest_corrections || false,
               parent_deprecated: @parent_deprecated
             ))
    end

    def deprecate_comments_help
      [
        :name_deprecate_comments_help.tp(name: @name.display_name.chomp(".")),
        :field_textile_link.tp
      ].safe_join
    end

    def form_action
      deprecate_synonym_of_name_path(@name.id,
                                     approved_name: model.proposed_name)
    end
  end
end
