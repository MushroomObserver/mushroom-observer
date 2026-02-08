# frozen_string_literal: true

# Form for creating donations (admin only).
# Allows admins to manually enter donation information.
class Components::DonationForm < Components::ApplicationForm
  def view_template
    super do
      text_field(:amount, size: 7, label: "#{:confirm_amount.t}:",
                          inline: true)
      text_field(:who, size: 50, label: "#{:WHO.t}:", inline: true)
      checkbox_field(:anonymous, label: :donate_anonymous.t)
      text_field(:email, size: 50, label: "#{:EMAIL.t}:", inline: true)
      submit(:create_donation_add.l, center: true)
    end
  end

  def form_action
    admin_donations_path
  end
end
