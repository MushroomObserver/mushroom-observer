# frozen_string_literal: true

# Renders errors.add(:field, :tag, **args) translation :tag at display
# time, instead of resolving eagerly via .t/.l at validation time.
#
# MO's tags live in a flat `mo.*` i18n scope. Rails' own
# generate_message never looks there - it only checks
# <i18n_scope>.errors.* and top-level errors.*.
#
# This overrides #message, not a separate resolver method. Every
# other entry point built on #message - full_message, full_messages,
# to_hash/as_json, errors[:attr], ActiveRecord::RecordInvalid#message
# - resolves MO tags correctly too, automatically.
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

    # Rails' own full_message rebuilds "attribute message" via a plain
    # I18n.t call that drops html_safe, even when #message above was
    # Textile-safe -- re-mark it so consumers like Components::Form::
    # Errors don't double-escape it.
    def full_message
      msg = message
      result = super
      msg.html_safe? ? result.html_safe : result # rubocop:disable Rails/OutputSafety
    end
  end
)

# errors.add's type should be a Symbol tag, like Rails internal error types.
# On MO, that means a translation string. To keep the API simple, there are no
# exceptions allowed. For internal/defensive errors, pass a :message kwarg.
ActiveModel::Errors.prepend(
  Module.new do
    def add(attribute, type = :invalid, **options)
      unless type.is_a?(Symbol)
        raise(ArgumentError.new("errors.add's type must be a Symbol tag, not " \
              "#{type.class} (#{type.inspect}) for :#{attribute} -- " \
              "resolution happens lazily at display time via " \
              "ActiveModel::Error#message, not eagerly here."))
      end

      super
    end
  end
)
