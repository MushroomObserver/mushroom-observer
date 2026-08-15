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

    # autocompleter-label-row goes on the OUTER row div only -- when
    # label_end is present that's this div; render_label_with_help
    # passes wrap_class: nil since it's nested content here, not the
    # outer row (see that method for why the class exists at all).
    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: "#{display} justify-content-between align-items-center " \
                 "autocompleter-label-row") do
        render_label_with_help(label_text, wrap_class: nil)
        render_label_end_slot
      end
    end

    # d-flex align-items-center -- without it, the label text and any
    # between/help content (autocompleter's has-id-indicator icon,
    # find/keep/edit buttons) are just inline siblings with no shared
    # vertical-alignment context, each at the mercy of its own
    # baseline/em-sizing quirks (an SVG icon's default vertical-align:
    # baseline doesn't actually sit on the text baseline the way a
    # real glyph does -- see autocompleter_field.rb).
    #
    # wrap_class defaults to autocompleter-label-row -- Bootstrap's
    # label carries margin-bottom: 5px with no top margin, which
    # throws off align-items-center centering against between-content
    # that has no margin of its own (see _autocomplete.scss). Inside
    # .autocompleter, the label's own margin is zeroed and the same
    # bottom spacing moves to this row wrapper instead. render_label_
    # flex_row passes wrap_class: nil so the class lands once, on
    # whichever div is actually the outer row.
    def render_label_with_help(label_text,
                               wrap_class: "autocompleter-label-row")
      div(class: class_names("d-flex", "align-items-center", wrap_class)) do
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
