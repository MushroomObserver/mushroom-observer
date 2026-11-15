# frozen_string_literal: true

module Views::Controllers::Images
  module Emails
    # Commercial-inquiry email form for one image.
    class New < Views::FullPageBase
      prop :image, ::Image
      prop :message, _Nilable(::String), default: nil

      def view_template
        add_title_with_name(:commercial_inquiry_title, name: @image)
        render(Form.new(
                 image: @image, user: current_user, message: @message
               ))
      end
    end
  end
end
