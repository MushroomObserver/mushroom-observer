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
# is already scoped to wherever that ancestor lives.
class ScssCrossFileSelectorFinder
  Finding = Struct.new(:selector, :files, keyword_init: true)

  # A line ending in "," is a selector-list continuation (e.g.
  # `th:first-child,`). A line matching `name: value` (and not ending
  # in ",") is a property declaration, which clears any pending
  # selector fragment, since it means a declaration list is in
  # progress, not a selector being built. Anything else -- e.g. the
  # first, comma-less line of a multi-line selector such as `.parent`
  # ahead of a `.child {` -- is buffered as a selector continuation.
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

      process_line(line, state, path, index)
    end
  end

  def process_line(line, state, path, index)
    if line.end_with?("{")
      state[:depth] = open_frame(state[:depth], line,
                                 state[:pending_selector], path, index)
    elsif line == "}"
      state[:depth] -= 1
    elsif !line.end_with?(",") && PROPERTY_RE.match?(line)
      state[:pending_selector].clear
    else
      state[:pending_selector] << line
    end
  end

  def open_frame(depth, line, pending_selector, path, index)
    text = (pending_selector + [line[0..-2].strip]).join(" ").strip
    pending_selector.clear
    if depth.zero? && !text.start_with?("@")
      split_selector_list(text).each do |s|
        index[s] << path unless index[s].include?(path)
      end
    end
    depth + 1
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
