# frozen_string_literal: true

# Turbo Frame content for the per-site "Shared with" accordion pane --
# the response body for `external_links#show` when requested with a
# `Turbo-Frame` request header. Renders a bold "On iNaturalist:" label
# followed by the site's own + sibling `ExternalLink` rows inside the
# frame the clicked badge targets. Purely informational, not a form.
module Views::Controllers::Observations::ExternalLinks
  class InfoFrame < Views::Base
    # A sibling observation's link to the same site, paired with the
    # sibling itself for the "(MO #N)" attribution.
    SiblingLink = Data.define(:link, :observation)

    prop :site_links, _Array(::ExternalLink)
    prop :sibling_site_links, _Array(SiblingLink), default: -> { [] }
    prop :frame_id, String
    prop :site_name, String

    def view_template
      turbo_frame_tag(@frame_id) { render_body }
    end

    private

    def render_body
      h5 do
        strong do
          plain("#{:show_observation_on_site.l(site: @site_name)}:")
        end
      end
      ul(class: "tight-list pl-0") do
        @site_links.each do |link|
          li(class: "hanging-indent") { Link(type: :external, link: link) }
        end
        @sibling_site_links.each { |sib_link| render_sibling_row(sib_link) }
      end
    end

    def render_sibling_row(sib_link)
      li(class: "hanging-indent") do
        Link(type: :external, link: sib_link.link)
        whitespace
        sibling_attribution(sib_link.observation)
      end
    end

    def sibling_attribution(sibling)
      small(class: "text-muted") do
        plain("(")
        a(href: permanent_observation_path(sibling.id)) do
          plain("MO #{sibling.id}")
        end
        plain(")")
      end
    end
  end
end
