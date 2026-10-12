# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared label row rendering for form field components
  module FieldLabelRow
    include Phlex::TrustedHtml

    # Three layouts: bare <label> (no appends/end), a d-flex wrap for
    # label+appends with no end, or d-flex justify-content-between for
    # label+appends on the left and label_end on the right. `between`
    # and `help` blocks are not part of this row -- see
    # FieldWrapperRendering and FieldWithHelp for those.
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
    # field's key, humanized. A bare Symbol still routes through `.t`
    # (not `.ti`-style title-casing) since some translations carry
    # textile markup that needs rendering, not casing.
    def resolved_label_text
      label_option = wrapper_options[:label]
      text = case label_option
             when Symbol then label_option.t
             when String then label_option
             else field.key.to_s.humanize
             end
      open_label_links_in_new_tab(text)
    end

    # A link inside a label would navigate away from a form mid-fill,
    # so force target="_blank" (+ rel="noopener noreferrer") instead
    # of stripping it -- a translator's Textile link syntax can land
    # here unaware it's inside a <label>. Browsers give a nested <a>
    # click priority over the label's toggle behavior, so this is safe.
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

    # Renders the .with_between slot as a block between the label row
    # and the field. Checkbox/radio fields don't call this -- their
    # between content renders inside/beside the field itself instead
    # (FieldWithHelp#render_between_slot).
    def render_between_block
      return unless respond_to?(:between_slot) && between_slot

      render(between_slot)
    end

    # Content inline with the label: the help-collapse trigger, a
    # `label_appends:` tag, or AutocompleterField's has-ID indicator
    # and find/keep/edit buttons. Distinct from `between` and `help`.
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
    def label_class(trailing_margin: true)
      base = if wrapper_options[:label_sr_only]
               "sr-only"
             else
               trailing_margin ? "mr-2" : nil
             end
      help_placement_above? ? class_names(base, "mb-0") : base
    end

    # help_placement: :above puts the help block between the label
    # row and the field, instead of after the field -- see
    # FieldWithHelp#render_help_after_field.
    def help_placement_above?
      wrapper_options[:help_placement] == :above
    end

    # label-row-with-appends goes on the OUTER row div only -- when
    # label_end is present that's this div; render_label_with_appends
    # passes wrap_class: nil since it's nested content here, not the
    # outer row (see below for what the class does).
    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: "#{display} justify-content-between align-items-center " \
                 "label-row-with-appends") do
        render_label_with_appends(label_text, wrap_class: nil)
        render_label_end_slot
      end
    end

    # d-flex align-items-center is needed since the label and appended
    # content are otherwise just inline siblings with no shared
    # vertical-alignment context. render_label_flex_row passes
    # wrap_class: nil since it already supplies that class.
    def render_label_with_appends(label_text,
                                  wrap_class: "label-row-with-appends")
      div(class: class_names("d-flex", "align-items-center", wrap_class)) do
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

      Help(element: :span, extra_class: "ml-2") do
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
