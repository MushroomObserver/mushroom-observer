# frozen_string_literal: true

module Views::Controllers::Licenses
  # New-license page — registers chrome and delegates to the
  # existing `Licenses::Form`.
  class New < Views::FullPageBase
    prop :license, ::License

    def view_template
      add_page_title(:create_license_title.l)
      add_context_nav(::Tab::License::FormNew.new)

      render(Form.new(@license))
    end
  end
end
