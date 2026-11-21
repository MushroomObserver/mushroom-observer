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
# Each line is split into "{"/"}"/";" -delimited segments rather than
# assumed to carry one rule-open/declaration/close apiece, so a
# single-line rule (".foo { color: red; }") is read the same way a
# multi-line one would be. Comma-separated selectors are split so
# each one is tracked independently, and a selector spanning
# multiple lines before its `{` is joined into one string first.
class ScssDuplicateSelectorFinder
  Finding = Struct.new(:key, :property, :locations, keyword_init: true)

  PROPERTY_RE = /\A([\w-]+)\s*:/

  # One file's scan state: the open `{`/`}` frame stack, any selector
  # lines buffered ahead of their `{`, and the shared result index.
  FileScan = Struct.new(:path, :frames, :pending_selector, :index,
                        keyword_init: true)

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
    @paths.each do |path|
      scan_file(FileScan.new(path: path, frames: [], pending_selector: [],
                             index: index))
    end
    index
  end

  def scan_file(scan)
    File.readlines(scan.path).each_with_index do |raw, idx|
      line = raw.strip
      next if line.empty? || line.start_with?("//")

      segments(line).each do |text, delim|
        process_segment(scan, text, delim, idx + 1)
      end
    end
  end

  def process_segment(scan, text, delim, line_no)
    case delim
    when "{" then open_frame(scan, text)
    when "}" then close_frame(scan, text, line_no)
    when ";" then record_or_buffer(scan, text, line_no)
    else scan.pending_selector << text
    end
  end

  # A ";"-terminated segment is always a declaration-like statement,
  # not a selector-list fragment (a selector is followed by more
  # selector text or "{", not ";") -- record it if it looks like a
  # property, otherwise drop it (e.g. a bare `@include foo;`).
  def record_or_buffer(scan, text, line_no)
    if (m = PROPERTY_RE.match(text))
      record_property(scan, m[1], line_no)
    elsif !text.empty?
      scan.pending_selector << text
    end
  end

  # Leftover text before "}" with no trailing ";" (the semicolon
  # before a rule's last declaration is optional) is still a
  # declaration to record, not a selector fragment to buffer.
  def close_frame(scan, text, line_no)
    record_or_buffer(scan, text, line_no)
    scan.frames.pop
  end

  def open_frame(scan, text_fragment)
    text = (scan.pending_selector + [text_fragment]).join(" ").strip
    scan.pending_selector.clear
    if text.start_with?("@")
      scan.frames.push(media: text, selectors: nil)
    else
      scan.frames.push(media: nil, selectors: split_selector_list(text))
    end
  end

  # Splits +line+ into (text, delimiter) pairs at each "{"/"}"/";",
  # so a single-line rule yields the same open/declare/close events a
  # multi-line one would across several lines. Sass interpolation
  # ("#{...}") is copied through as opaque text -- its braces aren't
  # rule delimiters. A trailing pair with a nil delimiter means the
  # line ended mid-selector or mid-declaration; it's carried to the
  # next line via pending_selector.
  def segments(line)
    chars = line.each_char.to_a
    parts = []
    buffer = +""
    i = 0
    i = consume_char(chars, i, buffer, parts) while i < chars.length
    parts << [buffer.strip, nil] unless buffer.strip.empty?
    parts
  end

  def consume_char(chars, idx, buffer, parts)
    char = chars[idx]
    return copy_interpolation(chars, idx, buffer) if char == "#" &&
                                                     chars[idx + 1] == "{"

    if %w[{ } ;].include?(char)
      parts << [buffer.strip, char]
      buffer.clear
    else
      buffer << char
    end
    idx + 1
  end

  # Copies "#{...}" (tracking any braces nested inside it) verbatim
  # into +buffer+ and returns the index just past its closing "}".
  def copy_interpolation(chars, start, buffer)
    buffer << '#{'
    i = start + 2
    depth = 1
    while i < chars.length && depth.positive?
      buffer << chars[i]
      depth += 1 if chars[i] == "{"
      depth -= 1 if chars[i] == "}"
      i += 1
    end
    i
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
  # wrapping it. A comma-separated ancestor (`.a, .b { .c { ... } }`)
  # keys on each ancestor selector separately -- joining them into
  # one string would miss a duplicate against a rule that reopens
  # `.c` under just `.a`.
  def record_property(scan, property, line_no)
    return unless innermost_selector_frame?(scan.frames)

    each_key(scan.frames) do |key|
      scan.index[key][property] << "#{scan.path}:#{line_no}"
    end
  end

  def each_key(frames, &block)
    media_prefix = media_conditions_prefix(frames)
    ancestor_combinations(frames).each do |ancestor_path|
      frames.last[:selectors].each do |selector|
        path = (ancestor_path + [selector]).join(" > ")
        yield("#{media_prefix} :: #{path}")
      end
    end
  end

  def media_conditions_prefix(frames)
    frames.filter_map { |f| f[:media] }.join(" / ")
  end

  def ancestor_combinations(frames)
    selector_frames = frames.reject { |f| f[:selectors].nil? }
    ancestor_lists = selector_frames[0..-2].pluck(:selectors)
    return [[]] if ancestor_lists.empty?

    ancestor_lists[0].product(*ancestor_lists[1..])
  end
end
