# frozen_string_literal: true

module Views::Controllers::Images
  module Licenses
    # Image-licenses updater page. Wrap of `Licenses::Form`.
    class Edit < Views::FullPageBase
      prop :form, ::FormObject::ImageLicenseUpdates
      prop :user, ::User

      def view_template
        add_page_title(:image_updater_title.t(user: @user.login))
        container_class(:wide)

        render(Form.new(@form, action: images_license_updater_path))
      end
    end
  end
end
