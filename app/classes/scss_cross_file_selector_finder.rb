# frozen_string_literal: true

# Scans a set of .scss files for a top-level selector (a class or id,
# not nested inside anything else) that opens a rule block in more
# than one file. A selector's meaning should not vary by which file
# happens to extend it -- a shared class reopened elsewhere to add
# context-specific behavior (e.g. `.flex-bar` inside
# `_autocomplete.scss` behaving differently than the definition in
# `_top_nav.scss`) makes the behavior depend on which other files
# happen to be loaded, and a reader looking at one definition has no
# way to know the other exists. Each such selector belongs in one
# file; a context that needs different behavior gets a distinct class
# name instead.
#
# Does not parse Sass -- no compiler, no asset pipeline involvement.
# Only tracks whether a selector sits at the top of the file (not
# nested inside another rule or an `@`-rule), since that is the
# question this check is about -- a selector nested under an ancestor
# is already scoped to wherever that ancestor lives. Each line is
# split into "{"/"}"/";" -delimited segments rather than assumed to
# carry one rule-open/declaration/close apiece, so a single-line rule
# (".foo { color: red; }") is read the same way a multi-line one
# would be.
class ScssCrossFileSelectorFinder
  Finding = Struct.new(:selector, :files, keyword_init: true)

  # A segment matching `name: value` is a property declaration,
  # which clears any pending selector fragment, since it means a
  # declaration list is in progress, not a selector being built.
  # Anything else -- e.g. the first, comma-less line of a multi-line
  # selector such as `.parent` ahead of a `.child {` -- is buffered
  # as a selector continuation.
  PROPERTY_RE = /\A[\w-]+\s*:/

  def self.call(paths)
    new(paths).call
  end

  def initialize(paths)
    @paths = paths
  end

  def call
    files_by_selector.filter_map do |selector, files|
      next if files.size < 2

      Finding.new(selector: selector, files: files.sort)
    end
  end

  private

  def files_by_selector
    index = Hash.new { |h, k| h[k] = [] }
    @paths.each { |path| scan_file(path, index) }
    index
  end

  def scan_file(path, index)
    state = { depth: 0, pending_selector: [] }
    File.readlines(path).each do |raw|
      line = raw.strip
      next if line.empty? || line.start_with?("//")

      segments(line).each do |text, delim|
        process_segment(text, delim, state, path, index)
      end
    end
  end

  def process_segment(text, delim, state, path, index)
    case delim
    when "{"
      state[:depth] = open_frame(state[:depth], text,
                                 state[:pending_selector], path, index)
    when "}"
      clear_or_buffer(text, state)
      state[:depth] -= 1
    when ";"
      clear_or_buffer(text, state)
    else
      state[:pending_selector] << text
    end
  end

  def clear_or_buffer(text, state)
    if PROPERTY_RE.match?(text)
      state[:pending_selector].clear
    elsif !text.empty?
      state[:pending_selector] << text
    end
  end

  def open_frame(depth, text_fragment, pending_selector, path, index)
    text = (pending_selector + [text_fragment]).join(" ").strip
    pending_selector.clear
    if depth.zero? && !text.start_with?("@")
      split_selector_list(text).each do |s|
        index[s] << path unless index[s].include?(path)
      end
    end
    depth + 1
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
end
