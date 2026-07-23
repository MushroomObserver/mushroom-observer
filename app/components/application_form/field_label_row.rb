# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared label row rendering for form field components
  module FieldLabelRow
    include Phlex::TrustedHtml

    # Three layouts depending on what extras the label row needs:
    #
    # - No between/help/label_end: bare `<label>` (no wrap div noise).
    # - Has between or help but no label_end: plain `<div>` wrap holding
    #   label + help + between inline — `justify-content-between` is
    #   meaningless without a right-side counterpart, so skip d-flex.
    # - Has label_end: d-flex with left (label+help+between) and right
    #   (label_end) children.
    def render_label_row(label_text, inline)
      if label_end_present?
        render_label_flex_row(label_text, inline)
      elsif label_extras_present?
        render_label_with_help(label_text)
      else
        label(for: field.dom.id, class: label_class) do
          render_label_content(label_text)
        end
      end
    end

    # Render label text, respecting HTML-safety
    def render_label_content(text)
      text.html_safe? ? trusted_html(text) : plain(text)
    end

    # Resolves `wrapper_options[:label]` to display text: an explicit
    # String wins as-is, a Symbol is translated via `.t`, otherwise the
    # field's key, humanized. Shared by every field type that takes a
    # `label:` option -- previously duplicated near-identically across
    # text_field.rb, textarea_field.rb, select_field.rb, and
    # file_field.rb.
    #
    # Most callers now pass an already-resolved String via `.ti`
    # (`label: :name.ti`) when they want a title-cased field-prompt
    # label -- `.ti` title-cases mechanically, so there's no longer a
    # separate ALL-CAPS twin tag to spell out. Passing a bare lowercase
    # Symbol (`label: :prefs_no_emails`) still works and goes through
    # this method's `.t` branch instead: some translations carry real
    # bold/italic textile markup (e.g. `prefs_no_emails`, "Opt out of
    # _all_ email from MO.") that needs textile rendering, not
    # title-casing, to display correctly.
    def resolved_label_text
      label_option = wrapper_options[:label]
      case label_option
      when Symbol then label_option.t
      when String then label_option
      else field.key.to_s.humanize
      end
    end

    # A resolved label containing a real link -- a field-PROMPT label
    # secretly doubling as a clickable link is a UX smell (not obviously
    # clickable, easy to miss). Route link content through a help icon
    # instead (see Components::Form::UploadGallery::Fields#render_license_field
    # for the established pattern) rather than embedding it in the label.
    #
    # Only guards `label_text` below (the colon-suffixed prompt path),
    # NOT `resolved_label_text` itself -- CheckboxField#label_text calls
    # `resolved_label_text` directly, bypassing this guard, because a
    # checkbox's label can be rich content rather than a plain text
    # prompt (e.g. a name link + copy-id badge next to a
    # synonym-selection checkbox -- see names/synonyms/form.rb).
    LINK_IN_LABEL_RE = /<a[\s>]/

    def raise_if_label_has_link(text)
      return unless text.is_a?(String) && text.match?(LINK_IN_LABEL_RE)

      raise("Field label contains a link -- move it into help: " \
            "content instead of embedding it in the label: #{text.inspect}")
    end

    # The standard trailing ":" on field-prompt labels (#4687) -- the
    # one place to change or delete it site-wide if we ever decide to.
    #
    # `[text, ":"].safe_join` rather than `"#{text}:"`: plain string
    # interpolation coerces an html_safe SafeBuffer label (e.g. Textile
    # markup from `resolved_label_text`'s `.t` call) back into an
    # unsafe String, so render_label_content would then escape it --
    # `safe_join` preserves the html_safe flag when `text` already
    # carries one, and safely escapes it when it doesn't.
    def append_colon(text)
      [text, ":"].safe_join
    end

    # Default label text: resolved text + colon, unless the caller
    # opts out via `label_colon: false` (e.g. SelectRangeField's "to"
    # connector between two selects, which reads as a word, not a
    # field prompt).
    def label_text
      text = resolved_label_text
      raise_if_label_has_link(text)
      wrapper_options[:label_colon] == false ? text : append_colon(text)
    end

    def label_end_present?
      respond_to?(:label_end_slot) && label_end_slot
    end

    def label_extras_present?
      has_between = between_slot || wrapper_options[:between]
      has_help = respond_to?(:help_slot) && help_slot
      has_between || has_help
    end

    # `wrapper_options[:label_sr_only] == true` hides the label
    # visually (Bootstrap's `sr-only`) but keeps the `<label for="…">`
    # association for screen readers. Use when the field's visible
    # label would be redundant — e.g. when a panel heading already
    # names the only field in the panel.
    def label_class
      wrapper_options[:label_sr_only] ? "sr-only" : "mr-3"
    end

    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: "#{display} justify-content-between") do
        render_label_with_help(label_text)
        render_label_end_slot
      end
    end

    def render_label_with_help(label_text)
      div do
        label(for: field.dom.id, class: label_class) do
          render_label_content(label_text)
        end
        render_help_in_label_row
        render_between_content
      end
    end

    def render_between_content
      render_between_option
      render(between_slot) if between_slot
    end

    def render_between_option
      between = wrapper_options[:between]
      return unless between

      Help(element: :span) { plain(between_text(between)) }
    end

    def between_text(between)
      [:optional, :required].include?(between) ? "(#{between.l})" : between
    end

    def render_label_end_slot
      return unless respond_to?(:label_end_slot) && label_end_slot

      render(label_end_slot)
    end
  end
end
