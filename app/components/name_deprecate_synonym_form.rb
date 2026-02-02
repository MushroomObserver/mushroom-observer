# frozen_string_literal: true

# Form for deprecating a name in favor of another
#
# @example
#   render(Components::NameDeprecateSynonymForm.new(
#     FormObject::DeprecateSynonym.new(proposed_name: @given_name),
#     name: @name,
#     context: { names: @names, valid_names: @valid_names, ... }
#   ))
#
class Components::NameDeprecateSynonymForm < Components::ApplicationForm
  def initialize(model, name:, context: {}, **)
    @name = name
    @names = context[:names]
    @valid_names = context[:valid_names]
    @suggest_corrections = context[:suggest_corrections]
    @parent_deprecated = context[:parent_deprecated]
    super(model, **)
  end

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
