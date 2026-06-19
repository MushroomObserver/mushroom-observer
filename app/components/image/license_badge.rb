# frozen_string_literal: true

# Tiny `<a><img/></a>` block displaying a license's badge with a
# link to its canonical URL. Used by description show pages
# (`DetailsAndAltsPanel`) and image show pages.
class Components::Image::LicenseBadge < Components::Base
  prop :license, ::License

  def view_template
    div(id: "license") do
      a(href: @license.url, rel: "license") do
        img(src: @license.badge_url,
            alt: @license.display_name,
            class: "border-none")
      end
    end
  end
end
