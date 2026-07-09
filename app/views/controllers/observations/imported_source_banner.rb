# frozen_string_literal: true

# Banner shown at the top of an Observation show page when the obs
# was imported from an external source (iNat, MyCoPortal, etc.).
# Rendered by `observations/show.rb`.
#
# Renders in its own panel with two pieces:
#  - "Imported from <Source>" — a single link to the per-observation
#    source URL. Off-site, so opens in a new tab.
#  - A (?) info icon — links to the MO docs article about imports
#    (article 39). On-site, so does NOT open in a new tab.
#
# Hides silently if the obs has no import link. The credit always
# renders as a link — an import link's URL is the stored override or
# derived from the site template, so it always resolves.
module Views::Controllers::Observations
  class ImportedSourceBanner < Views::Base
    HELP_ARTICLE_ID = 39

    prop :observation, Observation

    def view_template
      # One call: external_credit_link resolves the import link, its URL,
      # and the external id together (nil when not imported).
      return unless (link = @observation.external_credit_link)

      panel = Components::Panel.new(panel_class: "imported-source-banner")
      render(panel) do |panel|
        panel.with_body do
          render_credit(link)
          whitespace
          render_help_link
        end
      end
    end

    private

    def render_credit(link)
      Link(type: :external,
           content: credit_text(link),
           path: link[:url])
    end

    def credit_text(link)
      if link[:external_id].present?
        "#{link[:text]} #{link[:external_id]}"
      else
        link[:text]
      end
    end

    def render_help_link
      a(href: article_path(HELP_ARTICLE_ID),
        title: :source_credit_help_link.l,
        aria: { label: :source_credit_help_link.l }) do
        Icon(type: :question)
      end
    end
  end
end
