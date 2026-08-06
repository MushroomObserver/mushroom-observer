# frozen_string_literal: true

# Dummy test page for GH issue #3797: for every Components::Icon::GLYPHS
# entry, renders the current Bootstrap 3 Glyphicon next to its candidate
# replacement(s) in the licensed Glyphicons 2.0 sprites (vendor/assets/
# images/icons/, gitignored -- clone MushroomObserver/icon-library
# there first), so the team can pick which sprite variant to use per
# icon before Components::Icon gets converted to emit SVG <use> markup.
# Delete this whole page (controller, route, this file) once the picks
# are locked in.
#
# "Basic" and "halflings" are the two sprites Glyphicons 2.0 ships.
# Most icons exist in both -- often as genuinely different artwork, not
# just a duplicate -- which is exactly why this page exists instead of
# picking blind from grep output.
class Views::Controllers::TestPages::IconSpriteComparison::Show <
      Views::FullPageBase
  # [MO icon key, old Bootstrap glyphicon suffix, basic sprite id or
  # nil, halflings sprite id or nil]. Halflings ids ending "_N_" are
  # Illustrator's auto-disambiguation suffix from exporting the same
  # icon name into both sprites -- NOT a marker of a lesser variant,
  # the artwork genuinely differs from the basic version.
  ICON_ROWS = [
    [:add, "plus", "plus", "plus_1_"],
    [:edit, "edit", "square-edit", "square-edit"],
    [:delete, "remove-circle", "circle-empty-remove", nil],
    [:remove, "remove-circle", "circle-empty-remove", nil],
    [:trash, "trash", "bin", "bin_1_"],
    [:back, "step-backward", "chevron-last-left", "chevron-last-left"],
    [:show, "eye-open", "eye", "eye_1_"],
    [:hide, "eye-close", "eye-off", "eye-off_1_"],
    [:x, "remove", "menu-close", "menu-close_1_"],
    [:cancel, "remove", "times", "times_1_"],
    [:reuse, "share", "repeat", "repeat"],
    [:send, "send", "send", "send_1_"],
    [:log_in, "log-in", "log-in", "log-in_1_"],
    [:log_out, "log-out", "log-out", "log-out_1_"],
    [:admin, "text-background", "user-worker", nil],
    [:inbox, "inbox", "inbox", "inbox_1_"],
    [:interests, "bullhorn", "announcement", "announcement_1_"],
    [:tracking, "bullhorn", "announcement", "announcement_1_"],
    [:settings, "cog", "cogwheel", "cogwheel_1_"],
    [:ban, "ban-circle", "no-symbol", "no-symbol_1_"],
    [:plus, "plus-sign", "circle-plus", "circle-plus_1_"],
    [:minus, "minus-sign", "circle-minus", "circle-minus_1_"],
    [:email, "envelope", "envelope", "envelope_1_"],
    [:question, "question-sign", "circle-question", "circle-question_1_"],
    [:info, "question-sign", "circle-question", "circle-question_1_"],
    [:alert, "alert", "triangle-alert", "triangle-alert_1_"],
    [:list, "list", "list", "list_1_"],
    [:copy, "copy", "copy_1_", nil],
    [:clone, "duplicate", "block-move", nil],
    [:merge, "transfer", "exchange", "exchange_1_"],
    [:move, "random", "random", "random_1_"],
    [:synonyms, "random", "random", "random_1_"],
    [:adjust, "resize-vertical", "resize-vertical", nil],
    [:make_default, "star", "star", "star_1_"],
    [:publish, "upload", "circle-empty-up", nil],
    [:check, "ok-circle", "circle-empty-check", nil],
    [:deprecate, "ok-circle", "circle-empty-check", nil],
    [:approve, "exclamation-sign", "circle-alert", "circle-alert_1_"],
    [:manage_lists, "indent-left", "indent-left", "indent-left"],
    [:observations, "tags", "tags", nil],
    [:print, "print", "print", "print"],
    [:globe, "globe", "world-east", nil],
    [:map, "globe", "world-east", nil],
    [:place, "map-marker", "map-marker", "map-marker_1_"],
    [:find_on_map, "screenshot", "drop-plus", "drop-plus_1_"],
    [:apply, "check", "square-checkbox", "square-checkbox"],
    [:chevron_down, "chevron-down", "chevron-down", "chevron-down_1_"],
    [:chevron_up, "chevron-up", "chevron-up", "chevron-up_1_"],
    [:chevron_left, "chevron-left", "chevron-left", "chevron-left_1_"],
    [:chevron_right, "chevron-right", "chevron-right", "chevron-right_1_"],
    [:qrcode, "qrcode", "qr-code", "qr-code_1_"],
    [:mobile, "phone", "mobile-phone", "mobile-phone"],
    [:project, "th-list", "thumbnails-list", nil],
    [:download, "download-alt", "save-as", "save-as_1_"],
    [:new_window, "new-window", "square-new-window", "square-new-window"],
    [:search, "search", "search", "search_1_"],
    [:prev, "triangle-left", "chevron-left", "chevron-left_1_"],
    [:next, "triangle-right", "chevron-right", "chevron-right_1_"],
    [:goto, "share-alt", "step-forward", "step-forward"],
    [:grid, "th", "thumbnails-small", "thumbnails-small_1_"],
    [:menu, "align-justify", "menu", "menu_1_"],
    [:fullscreen, "fullscreen", "fullscreen", "fullscreen_1_"],
    [:matrix, "th-large", "thumbnails", "thumbnails_1_"],
    [:info_circle, "info-sign", "circle-info", "circle-info_1_"],
    [:user, "user", "user", "user_1_"]
  ].freeze

  ISSUE_URL = "https://github.com/MushroomObserver/mushroom-observer/" \
              "issues/3797"

  def view_template
    add_page_title("Icon sprite comparison (dummy test page, #3797)")
    render_explanation
    render_comparison_table
    render_bbox_fit_script
  end

  private

  def render_explanation
    p(class: "text-muted") do
      plain("Dummy comparison page for ")
      a(href: ISSUE_URL) { "GH #3797" }
      plain(" -- pick basic vs halflings per icon (or flag a better " \
            "candidate), then delete this page. \"_N_\" halflings ids " \
            "are Illustrator's export-collision suffix, not a lesser " \
            "variant -- the artwork genuinely differs from basic.")
    end
  end

  def render_comparison_table
    render(Components::Table.new(ICON_ROWS, variant: :striped)) do |t|
      t.column("MO key") { |row| key_cell(row) }
      t.column("Old suffix") { |row| old_suffix_cell(row) }
      t.column("Current (Glyphicon)") { |row| glyphicon_cell(row[0]) }
      t.column("Basic") { |row| sprite_cell("basic", row[2]) }
      t.column("Halflings") { |row| sprite_cell("halflings", row[3]) }
    end
  end

  def key_cell(row)
    code { row[0].to_s }
  end

  def old_suffix_cell(row)
    code { row[1] }
  end

  def glyphicon_cell(key)
    large_icon { render(Components::Icon.new(type: key)) }
  end

  def sprite_cell(sprite_name, id)
    return large_icon { plain("—") } if id.nil?

    path_data = TestPages::IconSpriteSvg.d_for(sprite_name, id)
    return large_icon { plain("id not found: #{id}") } if path_data.nil?

    large_icon do
      render(SpriteIcon.new(path_data: path_data))
      icon_caption("#{sprite_name}##{id}")
    end
  end

  def large_icon(&block)
    div(style: "font-size: 2.5rem;", &block)
  end

  def icon_caption(text)
    div(class: "small text-muted", style: "font-size: 0.9rem;") { text }
  end

  def render_bbox_fit_script
    script { trusted_html(TestPages::IconSpriteSvg.bbox_fit_script) }
  end
end
