# frozen_string_literal: true

module Views::Controllers::Admin::Donations
  # Form for creating donations (admin only). Rendered by the
  # admin/donations controller's `new.rb`. Allows admins to
  # manually enter donation information.
  class Form < ::Components::ApplicationForm
    def view_template
      super do
        text_field(:amount, size: 7, label: :confirm_amount,
                            inline: true)
        text_field(:who, size: 50, label: :WHO, inline: true)
        checkbox_field(:anonymous, label: :donate_anonymous)
        text_field(:email, size: 50, label: :EMAIL, inline: true)
        submit(:create_donation_add.l, center: true)
      end
    end

    def form_action
      admin_donations_path
    end
  end
end
