# frozen_string_literal: true

module Views::Controllers::Admin::Banners
  # Banner-management page. Heading + Form component.
  class Index < Views::FullPageBase
    prop :banner, ::Banner

    def view_template
      h1 { :change_banner_title.t }
      render(Form.new(@banner))
    end
  end
end
