# frozen_string_literal: true

# Renders an `<a>` for an `ExternalLink` AR record. iNaturalist
# observations show with an `iNat <id>` label (the rest of the URL
# after the iNat base URL); other external sites show as "On <site>"
# with a trailing date.
#
# Drop-in equivalent of `external_link(link)` in
# `app/helpers/link_helper.rb`. The helper now renders this component
# so existing ERB callers keep working unchanged.
#
# @example
#   render(Components::ExternalLink.new(link: external_link))
class Components::ExternalLink < Components::Base
  prop :link, ::ExternalLink

  def view_template
    if inaturalist?
      link_to(inat_text, @link.url)
    else
      link_to(:on_site.t(site: @link.external_site.name), @link.url)
      small { plain(" #{@link.created_at.web_date}") }
    end
  end

  private

  def inaturalist?
    @link.external_site.name == "iNaturalist"
  end

  # "iNat 12345" — the URL minus the iNat base URL is the obs id, so
  # this surfaces just the id rather than the full URL.
  def inat_text
    "iNat #{@link.url.sub(@link.external_site.base_url, "")}"
  end
end
