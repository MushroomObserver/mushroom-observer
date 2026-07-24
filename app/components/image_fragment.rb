# frozen_string_literal: true

# Single entry-point dispatcher for shared, `Image`-domain-specific
# display fragments with callers in more than one namespace (a
# Component and a raw controller turbo-stream response, or Components
# in different subtrees) — too specific to be a generic UI primitive,
# but not scoped to one controller either. See
# ".claude/rules/phlex_reference.md" for the general pattern.
#
#   ImageFragment(type: :vote_interface, user: @user, image: @image)
class Components::ImageFragment < Components::Base
  DISPATCH = {
    copyright: :Copyright,
    exif_link: :EXIFLink,
    lazy_vote_interface: :LazyVoteInterface,
    lightbox_caption: :LightboxCaption,
    original_link: :OriginalLink,
    reuse_form: :ReuseForm,
    vote_interface: :VoteInterface
  }.freeze

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    raise(ArgumentError.new(
            "Unknown ImageFragment type: #{kwargs[:type].inspect}. " \
            "Valid types: #{DISPATCH.keys.join(", ")}."
          ))
  end
end
