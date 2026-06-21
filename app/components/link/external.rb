# frozen_string_literal: true

# Anchor that opens in a new tab with `rel="noopener noreferrer"` baked in.
#
# Generic form (context-nav tabs, one-off external links):
#   render(Components::Link::External.new("GBIF", gbif_url))
#
# ExternalLink AR record form (observation external-links panel):
#   render(Components::Link::External.new(link: external_link))
#   # iNaturalist records render as "iNat <id>"; others as
#   # "On <site>" with a trailing <small> date.
#
# Via Tab PORO:
#   # Tab sets html_options: { external: true }
#   # Dispatcher routes here automatically.
class Components::Link::External < Components::Base
  def initialize(content = nil, path = nil, link: nil, **opts)
    super()
    @link = link
    @content = link ? link_content : content
    @path = link ? link.url : path
    @opts = opts
  end

  def view_template
    link_to(@path,
            target: "_blank",
            rel: "noopener noreferrer",
            **@opts) do
      plain(@content)
    end
    render_date if @link && !inaturalist?
  end

  private

  def link_content
    if inaturalist?
      "iNat #{@link.url.sub(@link.external_site.base_url, "")}"
    else
      :on_site.t(site: @link.external_site.name)
    end
  end

  def inaturalist?
    @link.external_site.name == "iNaturalist"
  end

  def render_date
    small { plain(" #{@link.created_at.web_date}") }
  end
end
