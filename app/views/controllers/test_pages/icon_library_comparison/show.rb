# frozen_string_literal: true

# Dummy test page for GH issue #3797: renders every semantic icon name
# MO currently uses (Components::Icon::GLYPHS) at large size, next to a
# candidate equivalent from Bootstrap Icons and Font Awesome Free, so
# the team can pick a replacement for the Bootstrap 3 Glyphicons by
# eyeballing them side by side. Delete this whole page (controller,
# route, this file) once the library is chosen.
#
# The two "candidate" columns are best-guess name pairings, not
# verified semantic matches -- that's the entire point of the page.
# Some MO icon keys reuse a glyph ironically (see icon.rb's comments on
# :deprecate/:approve); the candidates here just follow the glyph, not
# the ironic meaning.
class Views::Controllers::TestPages::IconLibraryComparison::Show <
      Views::FullPageBase
  BOOTSTRAP_ICONS_CSS =
    "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/" \
    "bootstrap-icons.min.css"
  FONT_AWESOME_CSS =
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/" \
    "all.min.css"

  # [MO icon key, Bootstrap Icons name (bi-<name>), Font Awesome Free
  # solid-style name (fa-<name>)], in the same order as Icon::GLYPHS.
  ICON_ROWS = [
    [:edit, "pencil-square", "pen-to-square"],
    [:delete, "x-circle", "circle-xmark"],
    [:add, "plus", "plus"],
    [:back, "chevron-bar-left", "backward-step"],
    [:show, "eye", "eye"],
    [:hide, "eye-slash", "eye-slash"],
    [:reuse, "box-arrow-up-right", "arrows-turn-right"],
    [:x, "x-lg", "xmark"],
    [:remove, "x-circle", "circle-xmark"],
    [:send, "send-fill", "paper-plane"],
    [:log_in, "box-arrow-in-right", "right-to-bracket"],
    [:log_out, "box-arrow-right", "right-from-bracket"],
    [:admin, "gear-wide-connected", "user-gear"],
    [:inbox, "inbox-fill", "inbox"],
    [:interests, "megaphone-fill", "bullhorn"],
    [:settings, "gear-fill", "gear"],
    [:ban, "ban", "ban"],
    [:plus, "plus-circle-fill", "circle-plus"],
    [:minus, "dash-circle-fill", "circle-minus"],
    [:trash, "trash3-fill", "trash"],
    [:cancel, "x-lg", "xmark"],
    [:email, "envelope-fill", "envelope"],
    [:question, "question-circle-fill", "circle-question"],
    [:alert, "exclamation-triangle-fill", "triangle-exclamation"],
    [:list, "list-ul", "list-ul"],
    [:copy, "clipboard2-check-fill", "clipboard-check"],
    [:clone, "copy", "copy"],
    [:merge, "arrow-left-right", "arrow-right-arrow-left"],
    [:move, "shuffle", "shuffle"],
    [:adjust, "arrows-vertical", "up-down"],
    [:make_default, "star-fill", "star"],
    [:publish, "arrow-up-circle", "circle-up"],
    [:check, "check-circle-fill", "circle-check"],
    [:deprecate, "check-circle-fill", "circle-check"],
    [:approve, "exclamation-circle-fill", "circle-exclamation"],
    [:synonyms, "shuffle", "shuffle"],
    [:tracking, "megaphone-fill", "bullhorn"],
    [:manage_lists, "list-columns-reverse", "list-check"],
    [:observations, "tags-fill", "tags"],
    [:print, "printer-fill", "print"],
    [:globe, "globe-americas", "earth-americas"],
    [:find_on_map, "crosshair", "location-crosshairs"],
    [:apply, "check2-square", "square-check"],
    [:chevron_down, "chevron-down", "chevron-down"],
    [:chevron_up, "chevron-up", "chevron-up"],
    [:chevron_left, "chevron-left", "chevron-left"],
    [:chevron_right, "chevron-right", "chevron-right"],
    [:qrcode, "qr-code", "qrcode"],
    [:mobile, "phone-fill", "mobile-screen-button"],
    [:project, "kanban-fill", "diagram-project"],
    [:download, "download", "download"],
    [:new_window, "box-arrow-up-right", "up-right-from-square"],
    [:search, "search", "magnifying-glass"],
    [:prev, "caret-left-fill", "caret-left"],
    [:next, "caret-right-fill", "caret-right"],
    [:goto, "arrow-90deg-right", "share"],
    [:grid, "grid-3x3-gap-fill", "table-cells"],
    [:menu, "list", "bars"],
    [:info, "question-circle-fill", "circle-question"],
    [:fullscreen, "arrows-fullscreen", "maximize"],
    [:matrix, "grid-3x3-gap-fill", "table-cells-large"],
    [:info_circle, "info-circle-fill", "circle-info"],
    [:user, "person-fill", "user"]
  ].freeze

  ISSUE_URL = "https://github.com/MushroomObserver/mushroom-observer/" \
              "issues/3797"

  def view_template
    add_page_title("Icon library comparison (dummy test page, #3797)")
    render_icon_library_stylesheets
    render_explanation
    render_comparison_table
  end

  private

  # Loading these via <link> in the body (not <head>) is invalid HTML
  # but works in every browser -- fine for a throwaway page; not worth
  # plumbing a content_for(:head) slot through the shared layout for
  # something this short-lived.
  def render_icon_library_stylesheets
    link(rel: "stylesheet", href: BOOTSTRAP_ICONS_CSS)
    link(rel: "stylesheet", href: FONT_AWESOME_CSS)
  end

  def render_explanation
    p(class: "text-muted") do
      plain("Dummy comparison page for ")
      a(href: ISSUE_URL) { "GH #3797" }
      plain(" -- pick an icon library, then delete this page. Candidate " \
            "names below are best guesses for visual comparison, not " \
            "verified semantic matches.")
    end
  end

  def render_comparison_table
    render(Components::Table.new(ICON_ROWS, variant: :striped)) do |t|
      t.column("MO icon key") { |row| code { row[0].to_s } }
      t.column("Current (Glyphicon)") { |row| glyphicon_cell(row[0]) }
      t.column("Bootstrap Icons") { |row| bootstrap_icons_cell(row[1]) }
      t.column("Font Awesome Free") { |row| font_awesome_cell(row[2]) }
    end
  end

  def glyphicon_cell(key)
    large_icon { render(Components::Icon.new(type: key)) }
  end

  def bootstrap_icons_cell(name)
    large_icon do
      i(class: "bi bi-#{name}")
      icon_caption("bi-#{name}")
    end
  end

  def font_awesome_cell(name)
    large_icon do
      i(class: "fa-solid fa-#{name}")
      icon_caption("fa-#{name}")
    end
  end

  def large_icon(&block)
    div(style: "font-size: 2.5rem;", &block)
  end

  def icon_caption(text)
    div(class: "small text-muted", style: "font-size: 0.9rem;") { text }
  end
end
