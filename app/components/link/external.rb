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
#   # (iNaturalist, MyCoPortal), that id follows as a sibling
#   # copy-to-clipboard IDBadge, not part of the link text -- a
#   # <button> nested inside the <a> would be invalid HTML and would
#   # double-fire the link's own navigation on a badge click.
#
# Via context-nav dispatcher:
#   # Tab sets html_options: { external: true }; dispatcher routes here.
class Components::Link::External < Components::Base
  # Keys from Tab::Base::ALLOWED_HTML_OPTION_KEYS that must not reach link_to.
  NON_HTML_OPTS = [:external, :button, :back, :icon, :help].freeze

  def initialize(content: nil, path: nil, tab: nil, link: nil, **opts)
    super()
    @link = link
    @site_record_id = nil
    if tab
      @content = tab.title
      @path = tab.path
      @opts = tab.html_options.except(*NON_HTML_OPTS).merge(opts)
    elsif link
      @content = relationship_text
      @site_record_id = link.site_record_id
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
    return unless @site_record_id

    whitespace
    IDBadge(value: @site_record_id, extra_class: nil)
  end

  private

  # "<date>: <relationship>" so rows read and sort by date.
  def relationship_text
    date = @link.relationship_date
    if date
      "#{date.web_date}: #{relationship_description}"
    else
      relationship_description
    end
  end

  # Presentational text built here (not on ExternalLink) since this is
  # its only caller -- e.g. "Copied by iNaturalist" / "Imported from
  # iNaturalist".
  def relationship_description
    :"external_link_relationship_#{@link.relationship}".l(
      site: @link.site_name
    )
  end
end
