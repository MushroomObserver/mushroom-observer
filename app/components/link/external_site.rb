# frozen_string_literal: true

# Renders an `<a>` to the user's matching record on an external
# mycology site, given an `ExternalLink` AR record. iNaturalist
# entries show with an `iNat <id>` label (URL minus the iNat base
# URL); other external sites show as "On <site>" with a trailing
# date.
#
# Named for the *destination* (an external site) rather than the
# AR record's class name (`ExternalLink`) — using the model's name
# would collide visually with `ExternalLink` and read as "ah, a
# component that wraps the model" rather than "a link to an
# external site".
#
# @example
#   render(Components::Link::ExternalSite.new(link: external_link))
class Components::Link::ExternalSite < Components::Base
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
