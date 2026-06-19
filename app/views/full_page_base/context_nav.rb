# frozen_string_literal: true

# Page's context-nav menu (formerly "tabset links" / "action menu" /
# "right-side dropdown"), mixed into `Views::FullPageBase`. Action
# views call `add_context_nav(links)` from their `view_template` to
# populate both `content_for(:context_nav)` (top-bar dropdown) and
# `content_for(:context_nav_mobile)` (offcanvas sidebar). The actual
# markup lives in `Views::Layouts::TopNav::ContextNav` and
# `Views::Layouts::Sidebar::ContextNav`; this method just renders
# them and stashes the result.
#
# `add_context_nav` accepts any of:
#
#   - an `Array` of `[text, url, args]` tuples (the legacy shape;
#     `app/helpers/tabs/*_helper.rb` methods return this — same
#     shape as `Tab::Base#to_a`)
#   - a `Tab::Collection` (each yielded `Tab::Base` converted via `#to_a`)
#   - a single `Tab::Base` instance (wrapped as a one-element list)
#
# where `args[:button]` (`:post` / `:destroy` / `:put` / `:patch` /
# nil) picks the HTML element the link renders as.
module Views::FullPageBase::ContextNav
  def add_context_nav(links)
    links = normalize_context_nav_links(links)
    return unless links&.compact&.any?

    links = links.compact
    top_nav_html = capture do
      render(::Views::Layouts::TopNav::ContextNav.new(links: links))
    end
    sidebar_html = capture do
      render(::Views::Layouts::Sidebar::ContextNav.new(links: links))
    end
    content_for(:context_nav) { top_nav_html }
    content_for(:context_nav_mobile) { sidebar_html }
  end

  private

  # Tab::Base / Tab::Collection inputs collapse to the legacy
  # `[text, url, args]` tuple-array shape the two ContextNav Phlex
  # views consume. Nil and Array (legacy callers) pass through.
  def normalize_context_nav_links(links)
    case links
    when nil then nil
    when ::Tab::Collection then links.map(&:to_a)
    when ::Tab::Base then [links.to_a]
    else links
    end
  end
end
