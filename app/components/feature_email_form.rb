# frozen_string_literal: true

# Form for sending feature emails to users.
# Allows admins to compose and send announcement emails about new features.
class Components::FeatureEmailForm < Components::ApplicationForm
  def initialize(model, users:, **)
    @users = users
    super(model, **)
  end

  def view_template
    super do
      p { "Sending to #{@users.length} users." }

      textarea_field(:content, label: "Feature Email:", rows: 20,
                               data: { autofocus: true })

      submit(:SEND.l, center: true)

      div(class: "form-group") do
        "#{:USERS.l}: #{user_logins}"
      end
    end
  end

  private

  def user_logins
    @users.map(&:login).join(", ")
  end

  def form_action
    url_for(controller: "admin/emails/features", action: :create,
            only_path: true)
  end
end
