# frozen_string_literal: true

module Views::Controllers::Admin::Banners
  # Banner-management page. Heading + Form component.
  class New < Views::FullPageBase
    prop :banner, ::Banner

    def view_template
      content_padding(:no_panels)

      h1 { :change_banner_title.t }
      render(Form.new(@banner))
    end
  end
end
