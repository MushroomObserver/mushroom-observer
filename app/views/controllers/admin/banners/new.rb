# frozen_string_literal: true

module Views::Controllers::Admin::Banners
  # Banner-management page. Heading + Form component.
  class New < Views::FullPageBase
    prop :banner, ::Banner

    def view_template
      add_new_title(:update_object, :banner)
      content_padding(:no_panels)

      render(Form.new(@banner))
    end
  end
end
