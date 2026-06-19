# frozen_string_literal: true

module Views::Controllers::Images
  module Emails
    # Commercial-inquiry email form for one image.
    class New < Views::FullPageBase
      prop :image, ::Image
      prop :message, _Nilable(::String), default: nil

      def view_template
        add_page_title(
          :commercial_inquiry_title.t(name: @image.unique_format_name)
        )
        render(Form.new(
                 image: @image,
                 user: current_user,
                 message: @message,
                 local: true
               ))
      end
    end
  end
end
