# frozen_string_literal: true

# Turbo-stream wrapper for the per-site "Shared with" info modal --
# the response body for `external_links#show` when requested with
# `format: :turbo_stream`. Composes `Components::Modal` with the
# site's own + sibling `ExternalLink` rows in the body slot. Purely
# informational, not a form.
#
# Lives as a thin wrapper because `ActionController#render` treats a
# trailing `do |x| ... end` block as a layout block rather than
# passing it through to the Phlex view's `view_template`; calling
# `Components::Modal` directly with slot setters from a controller
# action drops the slot configuration. This wrapper does the slot
# setup inside its own `view_template`, where the block IS forwarded.
module Views::Controllers::Observations::ExternalLinks
  class Modal < Views::Base
    # A sibling observation's link to the same site, paired with the
    # sibling itself for the "(MO #N)" attribution.
    SiblingLink = Data.define(:link, :observation)

    prop :site_links, _Array(::ExternalLink)
    prop :sibling_site_links, _Array(SiblingLink), default: -> { [] }
    prop :user, _Nilable(::User), default: nil
    prop :modal_id, String
    prop :title, String

    def view_template
      render(Components::Modal.new(
               id: @modal_id, user: @user
             )) do |modal|
        modal.with_title_content { trusted_html(@title) }
        modal.with_body { render_body }
      end
    end

    private

    def render_body
      ul(class: "tight-list") do
        @site_links.each { |link| li { Link(type: :external, link: link) } }
        @sibling_site_links.each { |sib_link| render_sibling_row(sib_link) }
      end
    end

    def render_sibling_row(sib_link)
      li do
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
