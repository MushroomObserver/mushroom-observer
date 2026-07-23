# frozen_string_literal: true

# Audit tool for issue #4867's en.txt purge: finds tags with no
# remaining reference anywhere, for a human to review before deleting.
# Run via `bin/rails lang:find_unused_tags`.
#
# Three checks, in order:
#
# 1. Whole-repo identifier-token scan -- a tag is a *candidate* only
#    if its exact name never appears as a bare identifier anywhere
#    outside en.txt/other locale files.
# 2. en.txt's own `[:tag]` / `[:tag(args)]` recursive-expansion macro
#    -- a tag referenced only from *within another tag's own value*
#    counts as used. This also covers a Symbol passed as a keyword
#    *argument* to another embedded tag (e.g. `field=:email_address`
#    inside `[:validate_too_long(field=:email_address,max=80)]`) --
#    `Symbol#localize_expand_arguments`'s `[Field]`/`[field]`
#    placeholder mechanism resolves that argument value via `.l`/`.ti`,
#    so it's a real reference even though it never appears as `[:tag]`
#    with a colon directly after the bracket. Missing this exact case
#    caused a real regression in the first purge PR (#4871) -- see
#    `email_address`.
# 3. Naive-pluralization risk -- `Symbol#localize_expand_arguments`
#    resolves a `[types]`/`[TYPES]` placeholder by naively appending
#    "s" to a singular Symbol argument and looking *that* up as a
#    tag (`:"#{val}s".l`). A tag matching `<other_tag>s` is protected.
#
# What this CANNOT find: genuine `:"prefix_#{var}_suffix"` dynamic
# symbol construction in Ruby code (`log_#{type}_#{event}`,
# `api_#{error_class_name}`, `prefs_#{field}`, etc.) -- there's no
# generic way to enumerate every possible `var` value short of full
# interpretation. KNOWN_DYNAMIC_* below is a manually maintained
# allowlist of prefixes/suffixes/substrings covering every such
# pattern found so far; extend it whenever a future purge round turns
# up a new one (the pattern to look for: grep the "confirmed unused"
# output against `git log -p`/the call site before trusting it, the
# same way the first two purge rounds did).
class Language::UnusedTagFinder
  Result = Struct.new(:total, :protected_tags, :confirmed_unused,
                      :files_scanned, keyword_init: true)

  # .claude is AI-assistant tooling/config, not application code or
  # even human-facing app documentation -- a tag name mentioned in a
  # rule file or scratch note isn't real usage evidence. Excluding it
  # also matters for a reason beyond accuracy: .claude/local/ is
  # gitignored, so any locally-present file there (a prior audit's
  # notes, say) is invisible to CI. Scanning it made local runs and CI
  # runs of this exact tool disagree -- local was silently masking
  # genuinely dead tags whenever a scratch note happened to mention
  # their name in prose.
  EXCLUDE_DIR_NAMES = %w[
    .git .bundle .ruby-lsp .vscode .qlty .claude coverage log tmp
    vendor node_modules
  ].freeze

  EXCLUDE_PATH_SUBSTRINGS = %w[
    /config/locales/ /public/design_test/ /public/images/
    /public/setup_images/ /public/test_server2/ /public/field_slips/
    /public/dwca/ /public/sitemap/ /docker/
  ].freeze

  BINARY_EXTENSIONS = %w[
    .gz .png .gif .xcf .ico .jpg .jpeg .rtf .DS_Store .woff .woff2
    .ttf .eot .zip .tar .db .sqlite3 .keep .pdf
  ].freeze

  MAX_SCANNED_FILE_SIZE = 3_000_000

  # Manually maintained -- see class comment. Each entry is a tag-name
  # test: a bare prefix/suffix/substring string, a [prefix, suffix]
  # pair (both must hold), or an exact tag name.
  KNOWN_DYNAMIC_PREFIXES = %w[
    rank_ rank_alt_ Rank_ query_ form_ review_
    runtime_description_added_ runtime_description_removed_
    add_members_ user_stats_ site_stats_ image_vote_ lifeform_
    external_link_relationship_ image_show_ prefs_filters_ prefs_
    rss_one_ visual_group_count_ show_location_ search_value_
    search_term_ pattern_ email_subject_occurrence_
    email_object_change_reason_ api_ source_credit_ log_
  ].freeze
  KNOWN_DYNAMIC_SUFFIXES = %w[_help _with_text _success _note].freeze
  KNOWN_DYNAMIC_SUBSTRINGS = %w[_term_ _title_].freeze
  KNOWN_DYNAMIC_PREFIX_SUFFIX_PAIRS = [
    %w[show_ _no_descriptions],
    %w[show_ _creator],
    %w[show_ _editor],
    %w[name_ _comment_summary],
    %w[email_occurrence_ _intro]
  ].freeze
  KNOWN_DYNAMIC_EXACT = %w[
    prev_object next_object
    change_member_status_make_member_help
    change_member_status_remove_member_help
    change_member_status_make_admin_help
  ].freeze

  def self.call
    new.call
  end

  def call
    tags = all_en_txt_tags
    tag_set = tags.to_set
    found = Set.new

    files_scanned = scan_codebase_identifiers(found)
    scan_en_txt_self_references(found)

    unused = tags.reject { |t| found.include?(t) }
    protected_tags, confirmed = unused.partition do |t|
      dynamically_protected?(t, tag_set)
    end

    Result.new(total: tags.size, protected_tags: protected_tags,
               confirmed_unused: confirmed.sort,
               files_scanned: files_scanned)
  end

  private

  def all_en_txt_tags
    en_txt.each_line.filter_map do |line|
      match = line.chomp.match(/\A\s{2}([a-zA-Z_]\w*):/)
      match && match[1]
    end
  end

  def en_txt_path
    Rails.root.join("config/locales/en.txt")
  end

  def en_txt
    @en_txt ||= File.read(en_txt_path)
  end

  # Every identifier token in the codebase (excluding locale files,
  # which trivially mirror every tag name as its own definition).
  def scan_codebase_identifiers(found)
    files_scanned = 0
    Rails.root.glob("**/*", File::FNM_DOTMATCH).each do |path|
      next unless scannable_file?(path)

      content = read_scrubbed(path)
      next if content.nil?

      files_scanned += 1
      content.scan(/[a-zA-Z_]\w*/) { |tok| found << tok }
    end
    files_scanned
  end

  def scannable_file?(path)
    return false unless path.file?

    rel = path.to_s
    return false if path.to_s.split("/").intersect?(EXCLUDE_DIR_NAMES)
    return false if rel.match?(Regexp.union(EXCLUDE_PATH_SUBSTRINGS))
    return false if BINARY_EXTENSIONS.any? { |ext| rel.end_with?(ext) }
    return false if path.size > MAX_SCANNED_FILE_SIZE

    true
  end

  def read_scrubbed(path)
    content = File.read(path, encoding: "UTF-8")
    return nil if content.include?("\x00")

    content.scrub("")
  end

  # `[:tag]` / `[:tag(args)]` references inside en.txt's own values,
  # including Symbol values passed as keyword arguments
  # (`field=:email_address`) -- see class comment, point 2.
  def scan_en_txt_self_references(found)
    en_txt.scan(/\[:([a-zA-Z_]\w*)/) { |m| found << m[0] }
    en_txt.scan(/\w+\s*=\s*:([a-zA-Z_]\w*)/) { |m| found << m[0] }
  end

  def dynamically_protected?(tag, tag_set)
    known_dynamic_tag?(tag) || naive_plural_of_real_tag?(tag, tag_set)
  end

  def known_dynamic_tag?(tag)
    KNOWN_DYNAMIC_PREFIXES.any? { |p| tag.start_with?(p) } ||
      KNOWN_DYNAMIC_SUFFIXES.any? { |s| tag.end_with?(s) } ||
      tag.match?(Regexp.union(KNOWN_DYNAMIC_SUBSTRINGS)) ||
      known_dynamic_prefix_suffix_pair?(tag) ||
      KNOWN_DYNAMIC_EXACT.include?(tag)
  end

  def known_dynamic_prefix_suffix_pair?(tag)
    KNOWN_DYNAMIC_PREFIX_SUFFIX_PAIRS.any? do |(prefix, suffix)|
      tag.start_with?(prefix) && tag.end_with?(suffix)
    end
  end

  # See class comment, point 3.
  def naive_plural_of_real_tag?(tag, tag_set)
    tag.end_with?("s") && tag_set.include?(tag[0..-2])
  end
end
