# frozen_string_literal: true

# Form for approving a deprecated name
#
# @example
#   render(Components::NameApproveSynonymForm.new(
#     FormObject::ApproveSynonym.new,
#     name: @name,
#     approved_names: @approved_names
#   ))
#
class Components::NameApproveSynonymForm < Components::ApplicationForm
  def initialize(model, name:, approved_names: nil, **)
    @name = name
    @approved_names = approved_names
    super(model, **)
  end

  def view_template
    submit(:APPROVE.l, center: true)

    render_approved_names_section if @approved_names.present?

    div(class: "help-note mr-3") do
      trusted_html(:name_approve_deprecate_help.tp)
    end

    textarea_field(:comment, label: "#{:name_approve_comments.l}:",
                             cols: 80, rows: 5, inline: true,
                             data: { autofocus: true })
    div(class: "help-note mr-3") do
      trusted_html(:name_approve_comments_help.tp(name: @name.display_name))
    end
  end

  private

  def render_approved_names_section
    checkbox_field(:deprecate_others, label: :name_approve_deprecate.l)
    p do
      @approved_names.each do |n|
        trusted_html(n.display_name.t)
        br
      end
    end
  end

  def form_action
    approve_synonym_of_name_path(@name.id)
  end
end
