# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared label row rendering for form field components
  module FieldLabelRow
    include Phlex::TrustedHtml

    # rubocop:disable MO/NoLongCommentBlock
    # Three layouts depending on what the label row itself needs:
    #
    # - No label_appends/label_end: bare `<label>` (no wrap div noise).
    # - Has label_appends but no label_end: `d-flex` wrap holding
    #   label + appends inline, no `justify-content-between` --
    #   meaningless without a right-side counterpart to space against.
    # - Has label_end: `d-flex justify-content-between` with left
    #   (label+appends) and right (label_end) children.
    #
    # `between` (block content between the label row and the field)
    # and `help` (the field's explanation block) are NOT part of the
    # label row — see FieldWrapperRendering and FieldWithHelp for
    # where they render instead.
    # rubocop:enable MO/NoLongCommentBlock
    def render_label_row(label_text, inline)
      if label_end_present?
        render_label_flex_row(label_text, inline)
      elsif label_appends_present?
        render_label_with_appends(label_text)
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
    # field's key, humanized.
    #
    # Callers wanting a title-cased field-prompt label pass an
    # already-resolved String via `.ti` (`label: :name.ti`). A bare
    # lowercase Symbol (`label: :prefs_no_emails`) goes through the
    # `.t` branch instead, since some translations carry bold/italic
    # textile markup that needs rendering, not title-casing (e.g.
    # "Opt out of _all_ email from MO.").
    def resolved_label_text
      label_option = wrapper_options[:label]
      text = case label_option
             when Symbol then label_option.t
             when String then label_option
             else field.key.to_s.humanize
             end
      open_label_links_in_new_tab(text)
    end

    # A link inside a label navigates the user away from a
    # partly-filled form, losing their input, so this forces
    # `target="_blank"` (plus `rel="noopener noreferrer"`) rather than
    # stripping the link: a translator writing ordinary Textile link
    # syntax into a label string (the `donate_who` Spanish translation
    # did this) has no way to know it lands in a `<label>`. Nested
    # links inside `<label for="...">` are valid HTML, and browsers
    # give the `<a>` click priority over the click-to-focus/toggle
    # behavior -- `CheckboxField#label_text` gets the same treatment
    # via `resolved_label_text`.
    LINK_TAG_RE = /<a\b([^>]*)>/i

    def open_label_links_in_new_tab(text)
      return text unless text.is_a?(String) && text.match?(LINK_TAG_RE)

      rewritten = text.gsub(LINK_TAG_RE) do
        attrs = Regexp.last_match(1)
        unless attrs.match?(/\btarget\s*=/i)
          attrs += ' target="_blank" rel="noopener noreferrer"'
        end
        "<a#{attrs}>"
      end
      return rewritten unless text.is_a?(ActiveSupport::SafeBuffer)

      ActiveSupport::SafeBuffer.new(rewritten)
    end

    # append_colon lives on Components::Localization, included into
    # FieldWithHelp (see field_with_help.rb) -- shared with label-style
    # text rendered outside of forms.

    # Default label text: resolved text + colon, unless the caller
    # opts out via `label_colon: false` (e.g. SelectRangeField's "to"
    # connector between two selects, which reads as a word, not a
    # field prompt).
    def label_text
      text = resolved_label_text
      wrapper_options[:label_colon] == false ? text : append_colon(text)
    end

    def label_end_present?
      respond_to?(:label_end_slot) && label_end_slot
    end

    # `between` (the .with_between slot) renders as a block, between
    # the label row and the field -- shared here so every field type
    # that declares slot :between calls the same one line, instead of
    # each hand-rolled render_with_wrapper repeating (and drifting
    # from) the same `render(between_slot) if between_slot`. Checkbox
    # and radio fields intentionally don't call this -- their between
    # content renders inside/beside the field itself (FieldWithHelp's
    # render_between_slot), a different layout by design.
    def render_between_block
      return unless respond_to?(:between_slot) && between_slot

      render(between_slot)
    end

    # Content that sits inline WITH the label, inside the label row's
    # flex container — the help-collapse trigger icon, a short
    # `label_appends:` tag ("(required)"/"(optional)"/a custom
    # string), and AutocompleterField's has-ID indicator + find/keep/
    # edit buttons (forwarded via `with_label_appends`). Distinct from
    # `between` (a block between the label row and the field) and
    # `help` (the field's explanation block) — neither belongs here.
    def label_appends_present?
      has_help_icon = respond_to?(:help_slot) && help_slot &&
                      wrapper_options[:help_collapse]
      has_appends_slot = respond_to?(:label_appends_slot) &&
                         label_appends_slot
      has_help_icon || has_appends_slot || wrapper_options[:label_appends]
    end

    # `wrapper_options[:label_sr_only] == true` hides the label
    # visually but keeps the `<label for="…">` association for screen
    # readers -- use when a panel heading already names the field.
    # `help_placement: :above` drops the label's bottom margin, since
    # the help block renders directly below it instead.
    # `trailing_margin: false` (render_label_with_appends) drops the
    # mr-2 too -- each append supplies a leading ml-2 instead.
    def label_class(trailing_margin: true)
      base = if wrapper_options[:label_sr_only]
               "sr-only"
             else
               trailing_margin ? "mr-2" : nil
             end
      help_placement_above? ? class_names(base, "mb-0") : base
    end

    # help_placement: :above puts the help block between the label
    # row and the field, instead of the default position after the
    # field -- see FieldWithHelp#render_help_after_field. Reads
    # wrapper_options directly (every field class exposes it via an
    # attr_reader) so this works regardless of which other modules a
    # field type includes.
    def help_placement_above?
      wrapper_options[:help_placement] == :above
    end

    # label-row-with-appends goes on the OUTER row div only -- when
    # label_end is present that's this div; render_label_with_appends
    # passes wrap_class: nil since it's nested content here, not the
    # outer row (see below for what the class does).
    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: class_names(
        "#{display} justify-content-between align-items-center",
        "label-row-with-appends", label_row_trailing_class
      )) do
        render_label_with_appends(label_text, wrap_class: nil)
        render_label_end_slot
      end
    end

    # An inline field (e.g. a select beside its label) needs trailing
    # space between the appends row and the input that follows it.
    # Applied once, on the outer row, so it doesn't compound with an
    # append's leading margin. `inline-trailing-space` is a stable
    # hook for tests to key off, independent of whichever margin
    # utility supplies the space.
    def label_row_trailing_class
      return nil unless wrapper_options[:inline]
      return nil unless respond_to?(:help_slot) && help_slot &&
                        wrapper_options[:help_collapse]

      class_names("mr-2", "inline-trailing-space")
    end

    # d-flex align-items-center is needed since the label and appended
    # content are otherwise just inline siblings with no shared
    # vertical-alignment context. render_label_flex_row passes
    # wrap_class: nil since it already supplies that class and already
    # applied label_row_trailing_class to its outer div.
    def render_label_with_appends(label_text,
                                  wrap_class: "label-row-with-appends")
      row_class = wrap_class && class_names(wrap_class,
                                            label_row_trailing_class)
      div(class: class_names("d-flex", "align-items-center", row_class)) do
        label(for: field.dom.id,
              class: label_class(trailing_margin: false)) do
          render_label_content(label_text)
        end
        render_help_in_label_row
        render_label_appends_content
      end
    end

    def render_label_appends_content
      render_label_appends_option
      return unless respond_to?(:label_appends_slot) && label_appends_slot

      render(label_appends_slot)
    end

    def render_label_appends_option
      appends = wrapper_options[:label_appends]
      return unless appends

      Help(element: :span, class: "ml-2") do
        plain(label_appends_text(appends))
      end
    end

    def label_appends_text(appends)
      [:optional, :required].include?(appends) ? "(#{appends.l})" : appends
    end

    def render_label_end_slot
      return unless respond_to?(:label_end_slot) && label_end_slot

      render(label_end_slot)
    end
  end
end
