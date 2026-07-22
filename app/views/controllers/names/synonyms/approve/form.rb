# frozen_string_literal: true

# Form for approving a deprecated name. Rendered by
# `Names::Synonyms::ApproveController#new`.
module Views::Controllers::Names::Synonyms::Approve
  class Form < ::Components::ApplicationForm
    def initialize(model, name:, approved_names: nil, user: nil, **)
      @name = name
      @approved_names = approved_names
      @user = user
      super(model, **)
    end

    def view_template
      submit(:approve.ti, center: true)

      render_approved_names_section if @approved_names.present?

      Help(content: :name_approve_deprecate_help.tp)

      textarea_field(:comment, label: :name_approve_comments,
                               cols: 80, rows: 5, inline: true,
                               data: { autofocus: true })
      Help(
        content: :name_approve_comments_help.tp(
          name: @name.display_name(@user)
        )
      )
    end

    private

    def render_approved_names_section
      checkbox_field(:deprecate_others, label: :name_approve_deprecate)
      p do
        @approved_names.each do |n|
          trusted_html(n.display_name(@user).t)
          br
        end
      end
    end

    def form_action
      approve_synonym_of_name_path(@name.id)
    end
  end
end
