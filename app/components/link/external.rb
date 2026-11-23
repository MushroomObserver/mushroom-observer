# frozen_string_literal: true

# Anchor that opens in a new tab with `rel="noopener noreferrer"` baked in.
#
# Generic form (context-nav tabs, one-off external links):
#   render(Components::Link::External.new(content: "GBIF", path: gbif_url))
#
# Tab PORO form (extracts title/path/html_options from the tab):
#   render(Components::Link::External.new(tab: some_tab))
#
# ExternalLink AR record form (observation external-links panel):
#   render(Components::Link::External.new(link: external_link))
#   # The link text leads with the relationship date, then the relationship:
#   # "<date>: <relationship>" (e.g. "2025-05-04: Imported from
#   # iNaturalist"). For sites with an id accessor on ExternalLink
#   # (iNaturalist, MyCoPortal), the caller renders that id as a sibling
#   # copy-to-clipboard Badge(variant: :id) -- this component only
#   # renders the link itself.
#
# Via context-nav dispatcher:
#   # Tab sets html_options: { external: true }; dispatcher routes here.
class Components::Link::External < Components::Base
  # Keys from Tab::Base::ALLOWED_HTML_OPTION_KEYS that must not reach link_to.
  NON_HTML_OPTS = [:external, :button, :back, :icon, :help].freeze

  prop :content, _Nilable(String), default: nil
  prop :path, _Nilable(String), default: nil
  prop :opts, _Hash(Symbol, _Any?), :**

  def initialize(content: nil, path: nil, tab: nil, link: nil, **opts)
    if tab
      content = tab.title
      path = tab.path
      opts = tab.html_options.except(*NON_HTML_OPTS).merge(opts)
    elsif link
      content = relationship_text(link)
      path = link.link_url
    end
    super(content: content, path: path, **opts)
  end

  def view_template
    link_to(@path,
            target: "_blank",
            rel: "noopener noreferrer",
            **@opts) do
      plain(@content)
    end
  end

  private

  # "<date>: <relationship>" so rows read and sort by date.
  def relationship_text(link)
    date = link.relationship_date
    if date
      "#{date.web_date}: #{relationship_description(link)}"
    else
      relationship_description(link)
    end
  end

  # Presentational text built here (not on ExternalLink) since this is
  # its only caller -- e.g. "Copied by iNaturalist" / "Imported from
  # iNaturalist".
  def relationship_description(link)
    :"external_link_relationship_#{link.relationship}".l(
      site: link.site_name
    )
  end
end
