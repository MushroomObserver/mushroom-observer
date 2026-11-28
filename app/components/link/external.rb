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
#   # copy-to-clipboard Badge(type: :id) -- this component only
#   # renders the link itself.
#
# Via context-nav dispatcher:
#   # Tab sets html_options: { external: true }; dispatcher routes here.
#
# Pass `icon:` (or a Tab whose `html_options` sets one) for an
# icon-only treatment -- `content:` becomes the sr-only label and
# hover tooltip instead of visible text, same as `Link::Get`.
class Components::Link::External < Components::Link
  # Keys from Tab::Base::ALLOWED_HTML_OPTION_KEYS that must not reach
  # link_to. `:icon` is consumed separately (see resolve_tab) --
  # still listed here so it doesn't also ride along into opts and
  # leak into link_to as a literal icon="..." attribute.
  NON_HTML_OPTS = [:external, :button, :back, :help, :icon].freeze

  prop :content, _Nilable(String), default: nil
  prop :path, _Nilable(String), default: nil
  prop :icon, _Nilable(_Union(*Components::Button::ICONS)), default: nil
  prop :opts, _Hash(Symbol, _Any?), :**

  def initialize(content: nil, path: nil, tab: nil, link: nil, **opts)
    icon = opts.delete(:icon)
    if tab
      content, path, icon, opts = resolve_tab(tab, icon, opts)
    elsif link
      content, path = resolve_link(link)
    end
    validate_icon_has_label!(icon, content)
    super(content: content, path: path, icon: icon, **opts)
  end

  def view_template
    link_to(@path, target: "_blank", rel: "noopener noreferrer",
                   **link_html_options) do
      render_link_content
    end
  end

  private

  # Icon-only rendering has no visible text, so content: is the only
  # accessible label it gets (sr-only span + hover tooltip) -- an
  # icon with no content would render with neither.
  def validate_icon_has_label!(icon, content)
    return unless icon && content.blank?

    raise(ArgumentError.new(
            "#{self.class} needs content: (or a tab with a title) " \
            "when icon: is given -- it becomes the icon's only " \
            "accessible label."
          ))
  end

  def resolve_tab(tab, icon, opts)
    [tab.title, tab.path, icon || tab.html_options[:icon],
     tab.html_options.except(*NON_HTML_OPTS).merge(opts)]
  end

  def resolve_link(link)
    [relationship_text(link), link.link_url]
  end

  def render_link_content
    if @icon
      render_icon_with_text(@icon, @content, show_label: @show_label)
    else
      plain(@content)
    end
  end

  def link_html_options
    base = { class: class_names(icon_wrapper_class, @opts[:class]) }
    base = base.deep_merge(tooltip_data) if @icon
    base.deep_merge(@opts.except(:class))
  end

  def tooltip_data
    { title: @content, data: { tooltip_target: "tip", placement: "top" } }
  end

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
