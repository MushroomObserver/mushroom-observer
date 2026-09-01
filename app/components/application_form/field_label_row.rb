# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared label row rendering for form field components
  module FieldLabelRow
    include Phlex::TrustedHtml

    # Three layouts depending on what the label row itself needs:
    #
    # - No label_appends/label_end: bare `<label>` (no wrap div noise).
    # - Has label_appends but no label_end: plain `<div>` wrap holding
    #   label + appends inline — `justify-content-between` is
    #   meaningless without a right-side counterpart, so skip d-flex.
    # - Has label_end: d-flex with left (label+appends) and right
    #   (label_end) children.
    #
    # `between` (block content between the label row and the field)
    # and `help` (the field's explanation block) are NOT part of the
    # label row — see FieldWrapperRendering and FieldWithHelp for
    # where they render instead.
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
      text = case label_option
             when Symbol then label_option.t
             when String then label_option
             else field.key.to_s.humanize
             end
      open_label_links_in_new_tab(text)
    end

    # A link inside a label navigates the user away from a form they may
    # be partway through filling out, in the same tab -- losing whatever
    # they'd already entered. Force `target="_blank"` (plus
    # `rel="noopener noreferrer"`) rather than stripping the link: a
    # translator writing ordinary Textile link syntax into a label
    # string (a production translation of `donate_who`, Spanish, did
    # exactly this) has no way to know it lands in a `<label>`, so the
    # label has to tolerate a link showing up, not reject it.
    #
    # Nested links inside a `<label for="...">` are valid HTML, and
    # browsers give the `<a>` click priority over the label's own
    # click-to-focus/toggle behavior, so there's no real ambiguity even
    # for a checkbox/radio label where the label click also toggles the
    # control -- CheckboxField#label_text calls resolved_label_text
    # directly and gets this same treatment.
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
    # visually (Bootstrap's `sr-only`) but keeps the `<label for="…">`
    # association for screen readers. Use when the field's visible
    # label would be redundant — e.g. when a panel heading already
    # names the only field in the panel.
    #
    # help_placement: :above drops the label's default bottom margin --
    # the help block renders immediately below it (see
    # FieldWithHelp#render_plain_help_text's matching mt-0), so the
    # usual label/field gap would otherwise double up between the
    # label and the help text instead.
    def label_class
      base = wrapper_options[:label_sr_only] ? "sr-only" : "mr-3"
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

    # autocompleter-label-row goes on the OUTER row div only -- when
    # label_end is present that's this div; render_label_with_appends
    # passes wrap_class: nil since it's nested content here, not the
    # outer row (see below for what the class does).
    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: "#{display} justify-content-between align-items-center " \
                 "autocompleter-label-row") do
        render_label_with_appends(label_text, wrap_class: nil)
        render_label_end_slot
      end
    end

    # d-flex align-items-center -- without it, the label text and any
    # appended content (autocompleter's has-id-indicator icon, find/
    # keep/edit buttons) are just inline siblings with no shared
    # vertical-alignment context, each subject to baseline/em-sizing
    # quirks (an SVG icon's default vertical-align: baseline doesn't
    # sit on the text baseline the way a rendered glyph does -- see
    # autocompleter_field.rb).
    #
    # wrap_class defaults to autocompleter-label-row -- Bootstrap's
    # label carries margin-bottom: 5px with no top margin, which
    # throws off align-items-center centering against append content
    # with no margin (see _autocomplete.scss). Inside .autocompleter,
    # the label's margin is zeroed and the same bottom spacing moves
    # to this row wrapper instead. render_label_flex_row passes
    # wrap_class: nil so the class lands once, on whichever div is the
    # outer row.
    def render_label_with_appends(label_text,
                                  wrap_class: "autocompleter-label-row")
      div(class: class_names("d-flex", "align-items-center", wrap_class)) do
        label(for: field.dom.id, class: label_class) do
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

      Help(element: :span) { plain(label_appends_text(appends)) }
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
