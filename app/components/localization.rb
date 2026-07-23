# frozen_string_literal: true

# Translation-key shortcuts for enum-like model attributes. Each
# method is a one-line `:"#{prefix}_#{value}".l` lookup — pulled into
# a single module so callers across components and views go through
# one named API instead of inlining the symbol-build dance everywhere.
#
# Included into `Components::Base` so every Phlex view / component
# has them available as plain methods (no helper proxy).
module Components::Localization
  # `Name#rank` → singular translation, e.g. `:genus` → "Genus".
  def rank_as_string(rank)
    :"rank_#{rank.to_s.downcase}".ti
  end

  # `Image#vote_cache` → longer translation including the "good
  # enough for a field guide" sentence. Returns textile source —
  # callers run `.t` after.
  def image_vote_as_long_string(val)
    :"image_vote_long_#{val || 0}".l
  end

  # `Image#vote_cache` → "Good enough for a field guide."-shaped
  # translation (no textile).
  def image_vote_as_help_string(val)
    :"image_vote_help_#{val || 0}".l
  end

  # `Image#vote_cache` → short label like "Good".
  def image_vote_as_short_string(val)
    :"image_vote_short_#{val || 0}".l
  end

  # A search/query field's form label, e.g. `:date` → "Date".
  def query_field_label(field_name)
    :"query_#{field_name}".l.humanize
  end

  # A query param's display name in the index filter caption, e.g.
  # `:by_user` → "By user".
  def query_param_label(key)
    :"query_#{key}".l
  end

  # `Name#lifeform`, one word, e.g. `"lichen"` → `:lifeform_lichen`. Returns
  # the translation key itself (not resolved) -- callers need both
  # `.l` (checkbox labels) and `.t` (plain display text) depending on
  # context, and `AuthorsAndEditors#user_list_title` also needs the
  # bare symbol to conditionally `.pluralize` before resolving it.
  def lifeform_key(word)
    :"lifeform_#{word}"
  end

  # `Name#lifeform`, one word's help text, e.g. `"lichen"` → the
  # textile-rendered explanation of what that lifeform means.
  def lifeform_help_as_string(word)
    :"lifeform_help_#{word}".t
  end

  # `type_tag` (e.g. `"name"`, `"location"`) → the textile-rendered
  # "no descriptions yet" empty-state text for that model type.
  def show_no_descriptions_as_string(type)
    :"show_#{type}_no_descriptions".t
  end

  # The one place to change or delete the standard trailing ":" on
  # label-style text site-wide, if we ever decide to (#4687 did this
  # for ApplicationForm field-prompt labels; this is the same thing
  # for label-style text rendered outside of forms). Also included
  # into `Components::ApplicationForm` directly (see that class's own
  # `include Phlex::TrustedHtml` for why -- it doesn't inherit
  # `Components::Base`, so this module has to be pulled in explicitly
  # there too).
  #
  # `[text, ":"].safe_join` rather than `"#{text}:"`: plain string
  # interpolation coerces an html_safe SafeBuffer (e.g. a `.ti`/`.t`
  # result carrying embedded textile/acronym markup) back into an
  # unsafe String, so the caller's rendering would then escape it --
  # `safe_join` preserves the html_safe flag when `text` already
  # carries one, and safely escapes it when it doesn't.
  def append_colon(text)
    [text, ":"].safe_join
  end
end
