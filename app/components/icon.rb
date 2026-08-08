# frozen_string_literal: true

# Renders an SVG icon via `<use>` against the MO icon sprite
# (vendor/assets/images/icons/mo-icons.svg, built by the private
# MushroomObserver/icon-library repo). Always carries `mo-icon` plus
# a per-type `mo-icon-<kebab-type>` class (e.g. `mo-icon-chevron-down`)
# -- tests and CSS should target the type class, not the `<use>`
# `href`: it asserts "this is the icon picked for :chevron_down",
# not which underlying sprite symbol currently backs that pick.
# Optionally adds a Bootstrap tooltip + an `aria-label` accessible name.
#
# @example Just the glyph
#   Icon(type: :globe)
#   # => <svg class="mo-icon mo-icon-globe">
#   #      <use href="...mo-icons-HASH.svg#globe"/>
#   #    </svg>
#
# @example With tooltip + accessible name + extra CSS
#   Icon(type: :edit, title: :edit.ti, class: "text-primary")
class Components::Icon < Components::Base
  # Valid icon keys. The sprite's own `<symbol id="...">` already
  # equals the key (see icon-library's script/build_sprite.rb), so
  # there's nothing left to map each key *to* -- this exists to
  # validate `type:` here, and for
  # test/classes/icon_glyph_sync_test.rb to check every key has real
  # artwork in the built sprite.
  GLYPHS = Set[
    :edit, :delete, :add, :back, :show, :hide, :reuse, :x, :remove,
    :send, :log_in, :log_out, :admin, :inbox, :interests, :settings,
    :ban, :plus, :minus, :trash, :cancel, :email, :question, :alert,
    :list, :copy, :clone, :merge, :move, :adjust, :make_default,
    :publish, :check, :deprecate, :approve, :synonyms, :tracking,
    :manage_lists, :observations, :print, :globe, :map, :place,
    :find_on_map, :apply, :chevron_down, :chevron_up, :chevron_left,
    :chevron_right, :qrcode, :mobile, :project, :download,
    :new_window, :search, :prev, :next, :goto, :grid, :menu, :info,
    :fullscreen, :matrix, :info_circle, :user
  ].freeze

  # vendor/assets/images/icons/mo-icons.svg only exists on disk when
  # fetched (CI's ICON_LIBRARY_PAT, or a dev's mo_sync_icon_library
  # sync) -- it's never committed (licensed derivative, kept out of
  # this public repo). Checked once at load time, not per-render: a
  # missing sprite means every icon renders nothing for the rest of
  # this process, same as an unrecognized `type:` already does, so a
  # transiently-absent file can't turn into a per-request 500.
  SPRITE_PATH = Rails.root.join("vendor/assets/images/icons/mo-icons.svg")
  SPRITE_AVAILABLE = File.exist?(SPRITE_PATH)

  prop :type, _Nilable(_Union(*GLYPHS.to_a)), default: nil
  prop :title, _Nilable(String), default: nil
  # Catch-all for class:, data:, aria:, and any other HTML attrs --
  # matches Components::Navbar/Collapsible's pattern (plain `class:`/
  # `data:` in, no separate `html_class:`/`data:` props needed).
  # `_Any?`, not bare `_Any` -- Literal's `_Any` excludes `NilClass`,
  # so a caller passing an explicit `key: nil` (not just omitting the
  # key) would otherwise raise a Literal::TypeError.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    return unless SPRITE_AVAILABLE && @type

    svg(class: svg_class, title: @title.presence, data: svg_data,
        aria: svg_aria,
        **@attributes.except(:class, :data, :aria)) do |s|
      # width/height: "100%" -- without it, browsers inconsistently
      # default <use>'s size against an em-sized (not pixel-sized)
      # parent <svg>, so CSS width/height changes on .mo-icon don't
      # reliably scale the referenced <symbol>.
      s.use(href: "#{asset_path("icons/mo-icons.svg")}##{@type}",
            width: "100%", height: "100%")
    end
  end

  private

  def svg_class
    class_names("mo-icon", "mo-icon-#{@type.to_s.tr("_", "-")}",
                @attributes[:class])
  end

  def svg_data
    data = @attributes[:data] || {}
    @title.present? ? { tooltip_target: "tip" }.merge(data) : data
  end

  # No `<title>` child -- browsers render an SVG's own `<title>` as a
  # native hover tooltip independently of Bootstrap's JS tooltip
  # (`svg_data`'s `tooltip_target`), which duplicated it. `title:` (the
  # HTML attribute above) stays for Bootstrap's tooltip text source --
  # its `fixTitle()` neutralizes that attribute as a native tooltip on
  # init. `aria-label` carries the persistent accessible name instead;
  # unlike `<title>` or `title=`, it never triggers a native tooltip.
  def svg_aria
    aria = @attributes[:aria] || {}
    @title.present? ? { label: @title }.merge(aria) : aria
  end
end
