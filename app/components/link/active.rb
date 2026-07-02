# frozen_string_literal: true

# Anchor wired up to the `nav-active` Stimulus controller. When the
# controller detects the current page URL matches this link, it adds
# `.active` to the anchor — used by the sidebar / top-nav to
# highlight which nav item the user is currently on. Allows nav
# fragments to be cached and reused across pages.
#
# Caller-supplied `data:` is deep-merged onto the nav-active wiring,
# so callers can add their own data attrs without overriding the
# Stimulus target/action attrs.
#
# @example
#   render(Components::Link::Active.new(content: "Latest",
#                                       path: observations_path))
#   render(Components::Link::Active.new(content: nil,
#                                       path: observations_path) { "Latest" })
class Components::Link::Active < Components::Base
  attr_reader :content, :path, :args

  def initialize(content:, path:, **args)
    super()
    @content = content
    @path = path
    @args = args
  end

  def view_template
    link_to(@path, **link_args) { trusted_or_plain(@content) }
  end

  private

  def link_args
    @args.deep_merge(data: nav_active_data)
  end

  def nav_active_data
    { nav_active_target: "link", action: "nav-active#navigate" }
  end

  # Content may be a textile-rendered html_safe string; `plain` would
  # re-escape it, `trusted_html` emits it as-is.
  def trusted_or_plain(text)
    if text.respond_to?(:html_safe?) && text.html_safe?
      trusted_html(text)
    else
      plain(text)
    end
  end
end
