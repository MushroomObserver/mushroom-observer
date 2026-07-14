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

  # [MO icon key, Font Awesome Free solid-style name (fa-<name>),
  # Bootstrap Icons name (bi-<name>)], in the same order as Icon::GLYPHS.
  # Font Awesome first: it's the front-runner candidate, so tuple order
  # matches display order (Current, FA, Bootstrap) -- keeps further
  # tweaks conceptually in sync with what's on screen.
  ICON_ROWS = [
    [:edit, "pen-to-square", "pencil-square"],
    [:delete, "circle-xmark", "x-circle"],
    [:add, "plus", "plus-lg"],
    [:back, "backward-step", "chevron-bar-left"],
    [:show, "eye", "eye"],
    [:hide, "eye-slash", "eye-slash"],
    [:reuse, "arrows-turn-right", "box-arrow-up-right"],
    [:x, "xmark", "x-lg"],
    [:remove, "circle-xmark", "x-circle"],
    [:send, "paper-plane", "send-fill"],
    [:log_in, "right-to-bracket", "box-arrow-in-right"],
    [:log_out, "right-from-bracket", "box-arrow-right"],
    [:admin, "a", "gear-wide-connected"],
    [:inbox, "inbox", "inbox-fill"],
    [:interests, "bullhorn", "megaphone-fill"],
    [:settings, "gear", "gear-fill"],
    [:ban, "ban", "ban"],
    [:plus, "circle-plus", "plus-circle-fill"],
    [:minus, "circle-minus", "dash-circle-fill"],
    [:trash, "trash-can", "trash3-fill"],
    [:cancel, "xmark", "x-lg"],
    [:email, "envelope", "envelope-fill"],
    [:question, "circle-question", "question-circle-fill"],
    [:alert, "triangle-exclamation", "exclamation-triangle-fill"],
    [:list, "list-ul", "list-ul"],
    [:copy, "clipboard-check", "clipboard2-check-fill"],
    [:clone, "copy", "copy"],
    [:merge, "arrow-right-arrow-left", "arrow-left-right"],
    [:move, "shuffle", "shuffle"],
    [:adjust, "up-down", "arrows-vertical"],
    [:make_default, "star", "star-fill"],
    [:publish, "circle-up", "arrow-up-circle"],
    [:check, "circle-check", "check-circle-fill"],
    [:deprecate, "circle-check", "check-circle-fill"],
    [:approve, "circle-exclamation", "exclamation-circle-fill"],
    [:synonyms, "shuffle", "shuffle"],
    [:tracking, "bullhorn", "megaphone-fill"],
    [:manage_lists, "list-check", "list-columns-reverse"],
    [:observations, "tags", "tags-fill"],
    [:print, "print", "printer-fill"],
    [:globe, "earth-americas", "globe-americas"],
    [:find_on_map, "location-crosshairs", "crosshair"],
    [:apply, "square-check", "check2-square"],
    [:chevron_down, "chevron-down", "chevron-down"],
    [:chevron_up, "chevron-up", "chevron-up"],
    [:chevron_left, "chevron-left", "chevron-left"],
    [:chevron_right, "chevron-right", "chevron-right"],
    [:qrcode, "qrcode", "qr-code"],
    [:mobile, "mobile-screen-button", "phone-fill"],
    [:project, "diagram-project", "kanban-fill"],
    [:download, "download", "download"],
    [:new_window, "up-right-from-square", "box-arrow-up-right"],
    [:search, "magnifying-glass", "search"],
    [:prev, "caret-left", "caret-left-fill"],
    [:next, "caret-right", "caret-right-fill"],
    [:goto, "share", "arrow-90deg-right"],
    [:grid, "table-cells", "grid-3x3-gap-fill"],
    [:menu, "bars", "list"],
    [:info, "circle-question", "question-circle-fill"],
    [:fullscreen, "maximize", "arrows-fullscreen"],
    [:matrix, "table-cells-large", "grid-3x3-gap-fill"],
    [:info_circle, "circle-info", "info-circle-fill"],
    [:user, "user", "person-fill"]
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
      t.column("Font Awesome Free") { |row| font_awesome_cell(row[1]) }
      t.column("Bootstrap Icons") { |row| bootstrap_icons_cell(row[2]) }
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
