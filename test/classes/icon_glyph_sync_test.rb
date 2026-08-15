# frozen_string_literal: true

require("test_helper")

# Confirms every Components::Icon::GLYPHS key has real artwork in the
# locally-fetched mo-icons.svg (built by the private
# MushroomObserver/icon-library repo -- see icon-library's
# script/build_sprite.rb). One-directional: the sprite is allowed to
# have icons the app doesn't reference yet, that's expected, not a bug.
class IconGlyphSyncTest < UnitTestCase
  def test_every_glyph_key_has_sprite_artwork
    unless File.exist?(Components::Icon::SPRITE_PATH)
      skip("mo-icons.svg not present -- run script/dev_setup_macos " \
           "--icons-only (requires icon-library access) to fetch it.")
    end

    doc = Nokogiri::XML(File.read(Components::Icon::SPRITE_PATH))
    doc.remove_namespaces!
    sprite_ids = doc.xpath("//symbol/@id").to_set(&:value)

    missing = Components::Icon::GLYPHS.map(&:to_s) - sprite_ids.to_a
    assert_empty(
      missing,
      "These Icon keys have no matching artwork in mo-icons.svg: " \
      "#{missing.join(", ")}. Add/fix them in icon-library's " \
      "sprite_map.yml, rebuild, and resync."
    )
  end
end
