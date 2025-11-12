# frozen_string_literal: true

# Form for user login
class Components::LoginForm < Components::ApplicationForm
  def view_template
    render_login_field
    render_password_field
    render_remember_me_field
    render_submit_button
    render_help_text
  end

  private

  def render_login_field
    text_field(:login, label: "#{:login_user.t}:", class: "mt-3",
                       data: { autofocus: @model.login.blank? })
  end

  def render_password_field
    password_field(:password, label: "#{:login_password.t}:", class: "mt-3",
                              data: { autofocus: @model.login.present? })
  end

  def render_remember_me_field
    checkbox_field(:remember_me, label: :login_remember_me.t, class: "mt-3")
  end

  def render_submit_button
    submit(:login_login.l, center: true)
  end

  def render_help_text
    div(class: "form-group mt-3") do
      :login_forgot_password.tp
      :login_having_problems.tp
    end
  end
end
