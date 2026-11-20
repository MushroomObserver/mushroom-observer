# frozen_string_literal: true

# Scans a set of .scss files for a selector that declares the same
# CSS property more than once in the same cascade position -- i.e.
# unconditionally, or nested inside the identical `@media` (or other
# `@`-rule) condition. That shape is a silent override: the later
# declaration wins and the earlier one is dead code, whether it's a
# byte-for-byte duplicate or two rules quietly fighting over one
# property. A selector legitimately reopened for *different*
# properties (the mobile-first base + responsive-override pattern,
# or a shared base block plus a per-variant block) is not flagged --
# that's additive, not competing.
#
# Does not parse Sass -- no compiler, no asset pipeline involvement.
# Plain line-based brace tracking, same approach as a text-based
# RuboCop cop. Comma-separated selectors are split so each one is
# tracked independently, and a selector spanning multiple lines
# before its `{` is joined into one string first.
class ScssDuplicateSelectorFinder
  Finding = Struct.new(:key, :property, :locations, keyword_init: true)

  PROPERTY_RE = /\A([\w-]+)\s*:/

  # One file's scan state: the open `{`/`}` frame stack, any selector
  # lines buffered ahead of their `{`, and the shared result index.
  FileScan = Struct.new(:path, :frames, :pending_selector, :index) do
    def initialize(path:, index:)
      super(path, [], [], index)
    end
  end

  def self.call(paths)
    new(paths).call
  end

  def initialize(paths)
    @paths = paths
  end

  def call
    findings = []
    properties_by_key.each do |key, by_property|
      by_property.each do |property, locations|
        next if locations.size < 2

        findings << Finding.new(key: key, property: property,
                                locations: locations)
      end
    end
    findings
  end

  private

  # key => { "property-name" => ["file:line", ...] }
  def properties_by_key
    index = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
    @paths.each { |path| scan_file(FileScan.new(path: path, index: index)) }
    index
  end

  def scan_file(scan)
    File.readlines(scan.path).each_with_index do |raw, idx|
      line = raw.strip
      next if line.empty? || line.start_with?("//")

      process_line(scan, line, idx + 1)
    end
  end

  # A line ending in "," is a selector-list continuation (e.g.
  # `th:first-child,`), not a property declaration -- its leading
  # pseudo-class can otherwise look like one to PROPERTY_RE.
  def process_line(scan, line, line_no)
    if line.end_with?("{")
      open_frame(scan, line)
    elsif line == "}"
      scan.frames.pop
    elsif !line.end_with?(",") && (m = PROPERTY_RE.match(line))
      record_property(scan, m[1], line_no)
    else
      scan.pending_selector << line
    end
  end

  def open_frame(scan, line)
    text = (scan.pending_selector + [line[0..-2].strip]).join(" ").strip
    scan.pending_selector.clear
    if text.start_with?("@")
      scan.frames.push(media: text, selectors: nil)
    else
      scan.frames.push(media: nil, selectors: split_selector_list(text))
    end
  end

  # A plain `text.split(",")` also splits inside `:not(.a, .b)`-style
  # parens, which aren't a selector-list boundary -- only split on a
  # comma seen at paren depth 0.
  def split_selector_list(text)
    parts = []
    buffer = +""
    depth = 0
    text.each_char do |char|
      depth += 1 if char == "("
      depth -= 1 if char == ")"
      if char == "," && depth.zero?
        parts << buffer
        buffer = +""
      else
        buffer << char
      end
    end
    parts << buffer
    parts.map(&:strip).reject(&:empty?)
  end

  # A property declared directly inside an `@`-rule frame (e.g. a
  # bare custom-property assignment with no wrapping selector) has
  # no selector to key on.
  def innermost_selector_frame?(frames)
    frames.any? && frames.last[:selectors]
  end

  # Attributes a property declaration to every selector in scope --
  # each selector on the innermost frame, combined with every
  # ancestor selector frame (so `.a .b { color: red }` keys on the
  # full `.a > .b` path, not bare `.b`) and every `@`-rule condition
  # wrapping it.
  def record_property(scan, property, line_no)
    return unless innermost_selector_frame?(scan.frames)

    key_prefix = selector_key_prefix(scan.frames)
    scan.frames.last[:selectors].each do |selector|
      key = "#{key_prefix} > #{selector}"
      scan.index[key][property] << "#{scan.path}:#{line_no}"
    end
  end

  def selector_key_prefix(frames)
    media_conditions = frames.filter_map { |f| f[:media] }
    ancestor_path = ancestor_selector_path(frames)
    "#{media_conditions.join(" / ")} :: #{ancestor_path.join(" > ")}"
  end

  def ancestor_selector_path(frames)
    selector_frames = frames.reject { |f| f[:selectors].nil? }
    selector_frames[0..-2].map { |f| f[:selectors].join(",") }
  end
end
