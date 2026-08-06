# frozen_string_literal: true

# Extracts individual <path> "d" attribute data from the licensed
# Glyphicons 2.0 sprite files (vendor/assets/images/icons/,
# gitignored) for the throwaway TestPages::IconSpriteComparison page
# (GH #3797) -- delete alongside it once the sprite-variant picks are
# locked in.
#
# These are absolute-grid-coordinate sprites (every path shares one
# huge canvas), not <symbol>s with a local viewBox, so each extracted
# path still needs a per-icon viewBox fitted client-side -- see
# app/views/controllers/test_pages/icon_sprite_comparison/show.rb's
# bbox-fit script.
module TestPages::IconSpriteSvg
  SPRITE_DIR = Rails.root.join("vendor/assets/images/icons")

  # Returns the "d" attribute string for `id` within `sprite_name`
  # ("basic" or "halflings"), or nil if the id isn't in that sprite
  # (missing files, e.g. icon-library not cloned locally, are treated
  # the same as a missing id).
  def self.d_for(sprite_name, id)
    return nil if id.nil?

    path_data_for(sprite_name)[id]
  end

  def self.path_data_for(sprite_name)
    @path_data ||= {}
    @path_data[sprite_name] ||= extract_path_data(sprite_name)
  end
  private_class_method :path_data_for

  def self.extract_path_data(sprite_name)
    file = SPRITE_DIR.join("glyphicons-#{sprite_name}.svg")
    return {} unless File.exist?(file)

    doc = Nokogiri::XML(File.read(file))
    doc.remove_namespaces!
    doc.xpath("//path[@id]").to_h { |node| [node["id"], node["d"]] }
  end
  private_class_method :extract_path_data

  # Fits each sprite-icon SVG's viewBox to its actual path bounding
  # box via the browser's own SVG geometry (getBBox) -- far more
  # reliable than reimplementing path-bounds math server-side for a
  # throwaway page. No untrusted interpolation -- a static script, so
  # a plain SafeBuffer wrap is enough (see Phlex::TrustedHtml).
  #
  # 2% padding, not the original 8%: confirmed via real screenshot
  # pixel measurements (not browser-side ink measurement, which
  # proved unreliable) that 8% was needlessly eating into the same
  # budget the 2.8rem height fix (see sprite_icon.rb) was trying to
  # recover -- font glyphs render close to edge-to-edge in their box.
  def self.bbox_fit_script
    <<~JS.html_safe
      document.querySelectorAll(".sprite-icon-fit").forEach((svg) => {
        const path = svg.querySelector("path");
        const box = path.getBBox();
        const pad = Math.max(box.width, box.height) * 0.02;
        svg.setAttribute(
          "viewBox",
          [box.x - pad, box.y - pad, box.width + 2 * pad, box.height + 2 * pad].join(" ")
        );
      });
    JS
  end
end
