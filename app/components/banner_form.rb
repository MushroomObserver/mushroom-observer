# frozen_string_literal: true

# Form for admins to create or update site-wide banners.
# Displays a textarea for the banner message with a submit button.
# Always creates a new banner record (with incremented version) rather than
# updating existing records, so always uses POST method.
class Components::BannerForm < Components::ApplicationForm
  def initialize(model, **)
    super(model, method: :post, **)
  end

  def view_template
    super do
      textarea_field(
        :message,
        label: nil,
        rows: 5
      )
      submit(:banner_update.l, center: true)
    end
  end

  def form_action
    admin_banners_path
  end
end
