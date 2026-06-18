# frozen_string_literal: true

module Views::Controllers::Theme
  # BlackOnWhite color-theme description page.
  class BlackOnWhite < Views::FullPageBase
    def view_template
      add_page_title(:theme_black_on_white.tl)
      add_context_nav(::Tab::Theme::ShowActions.new)

      trusted_html(build_description)
      trusted_html(:theme_switch.tp(theme: :BlackOnWhite.l))
    end

    private

    def build_description
      link_html = capture do
        link_to({ action: :Amanita }) { trusted_html("**__Amanita__**".t) }
      end
      textile = :theme_black_on_white_description.tp(link: "XXX")
      ::ActiveSupport::SafeBuffer.new(textile.to_s.sub("XXX", link_html))
    end
  end
end
