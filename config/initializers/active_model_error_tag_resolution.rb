# frozen_string_literal: true

# Lets errors.add(:field, :some_mo_tag, **interpolation_args) defer tag
# resolution to display time instead of pre-resolving via .t/.l/.ti/.tl
# at validation time. MO's tags live in a flat `mo.*` i18n scope
# (MO.locale_namespace) that Rails' own ActiveModel::Error#message ->
# generate_message resolution chain has no path to - no model sets
# i18n_scope, and generate_message only ever probes
# <i18n_scope>.errors.* / top-level errors.*, never mo.*.
#
# Overriding #message (rather than adding a separate resolver method
# elsewhere that callers have to remember to use) means every other
# Rails/ActiveModel entry point built on top of it - full_message,
# full_messages, to_hash/as_json, errors[:attr], even
# ActiveRecord::RecordInvalid#message - resolves MO tags correctly for
# free, with nothing for a future caller to get wrong.
ActiveModel::Error.prepend(
  Module.new do
    def message
      if raw_type.is_a?(Symbol) && raw_type.has_translation?
        return options[:message] if options[:message].is_a?(String)
        return super if options[:message].is_a?(Proc)

        # .t, not .l: several mo.* error tags rely on Textile
        # formatting (e.g. runtime_lat_long_error's embedded
        # newlines only become <br /> via Textile's paragraph
        # handling), so resolution can't skip it tag-by-tag.
        return raw_type.t(**options.except(:message))
      end

      super
    end
  end
)
