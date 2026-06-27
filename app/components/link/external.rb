# frozen_string_literal: true

# Anchor that opens in a new tab with `rel="noopener noreferrer"` baked in.
#
# Generic form (context-nav tabs, one-off external links):
#   render(Components::Link::External.new("GBIF", gbif_url))
#
# Tab PORO form (extracts title/path/html_options from the tab):
#   render(Components::Link::External.new(tab: some_tab))
#
# ExternalLink AR record form (observation external-links panel):
#   render(Components::Link::External.new(link: external_link))
#   # The relationship IS the link text: iNaturalist records render as
#   # "<relationship> (<id>)" (e.g. "Imported from iNaturalist (12345)");
#   # other sites as "<relationship>" with a trailing <small> date.
#
# Via context-nav dispatcher:
#   # Tab sets html_options: { external: true }; dispatcher routes here.
class Components::Link::External < Components::Base
  # Keys from Tab::Base::ALLOWED_HTML_OPTION_KEYS that must not reach link_to.
  NON_HTML_OPTS = [:external, :button, :back, :icon, :help].freeze

  def initialize(content = nil, path = nil, tab: nil, link: nil, **opts)
    super()
    @link = link
    if tab
      @content = tab.title
      @path = tab.path
      @opts = tab.html_options.except(*NON_HTML_OPTS).merge(opts)
    elsif link
      @content = link_content
      @path = link.link_url
      @opts = opts
    else
      @content = content
      @path = path
      @opts = opts
    end
  end

  def view_template
    link_to(@path,
            target: "_blank",
            rel: "noopener noreferrer",
            **@opts) do
      plain(@content)
    end
    render_date if @link
  end

  private

  # Import links store external_id with a nil url (the url is derived), while
  # manual links store the url. link_url resolves both, so strip the base_url
  # off it to get the bare iNat id either way.
  def link_content
    return @link.relationship_description unless inaturalist?

    id = @link.link_url.delete_prefix(@link.external_site.base_url)
    "#{@link.relationship_description} (#{id})"
  end

  def inaturalist?
    @link.external_site.name == "iNaturalist"
  end

  def render_date
    date = @link.relationship_date or return

    small { plain(" #{date.web_date}") }
  end
end
