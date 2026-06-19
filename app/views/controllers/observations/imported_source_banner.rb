# frozen_string_literal: true

# Banner shown at the top of an Observation show page when the obs
# was imported from an external source (iNat, MyCoPortal, etc.).
# Rendered by `observations/show.html.erb`.
#
# Renders in its own panel with two pieces:
#  - "Imported from <Source>" — a single link to the per-observation
#    source URL. Off-site, so opens in a new tab.
#  - A (?) info icon — links to the MO docs article about imports
#    (article 39). On-site, so does NOT open in a new tab.
#
# Hides silently if the obs has no import link. If the link has no
# URL, the credit is rendered as plain text without a link; the (?)
# widget still appears.
module Views::Controllers::Observations
  class ImportedSourceBanner < Views::Base
    HELP_ARTICLE_ID = 39

    prop :observation, Observation

    def view_template
      return unless @observation.import_link

      link = @observation.external_credit_link
      panel = Components::Panel.new(panel_class: "imported-source-banner")
      render(panel) do |panel|
        panel.with_body do
          render_credit(link)
          plain(" ")
          render_help_link
        end
      end
    end

    private

    def render_credit(link)
      a(href: link[:url], target: "_blank",
        rel: "noopener noreferrer") { credit_text(link) }
    end

    def credit_text(link)
      external_id = @observation.import_link&.external_id
      if external_id.present?
        "#{link[:text]} #{external_id}"
      else
        link[:text]
      end
    end

    def render_help_link
      a(href: article_path(HELP_ARTICLE_ID),
        title: :source_credit_help_link.l,
        aria: { label: :source_credit_help_link.l }) do
        render(Components::Icon.new(type: :question))
      end
    end
  end
end
