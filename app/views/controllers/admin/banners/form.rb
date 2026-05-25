# frozen_string_literal: true

module Views::Controllers::Admin::Banners
  # Form for admins to create or update site-wide banners. Rendered
  # by the admin/banners controller's `index.html.erb`. Displays a
  # textarea for the banner message with a submit button. Always
  # creates a new banner record (with incremented version) rather
  # than updating existing records, so always uses POST method.
  class Form < ::Components::ApplicationForm
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
end
