# frozen_string_literal: true

# Form for deprecating a name in favor of another.
# Creates its own FormObject internally from the provided kwargs.
#
# @example
#   render(Components::NameDeprecateSynonymForm.new(
#     name: @name,
#     proposed_name: @given_name,
#     is_misspelling: @misspelling,
#     comment: @comment,
#     names: @names,
#     valid_names: @valid_names
#   ))
#
class Components::NameDeprecateSynonymForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(name:, proposed_name: nil, is_misspelling: false, comment: nil,
                 names: [], valid_names: [], suggest_corrections: false,
                 parent_deprecated: nil, **)
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

    proposed_label = "#{:name_deprecate_preferred.l}:"
    autocompleter_field(:proposed_name,
                        type: :name, label: proposed_label,
                        inline: true, data: { autofocus: true })
    help_note(:div, :name_deprecate_preferred_help.tp)

    checkbox_field(:is_misspelling, label: :form_names_misspelling.l)

    textarea_field(:comment, label: "#{:name_deprecate_comments.l}:",
                             cols: 80, rows: 5, inline: true)
    help_note(:div, deprecate_comments_help)
  end

  private

  def render_name_feedback
    render(Components::FormNameFeedback.new(
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
    deprecate_synonym_of_name_path(@name.id, approved_name: model.proposed_name)
  end
end
