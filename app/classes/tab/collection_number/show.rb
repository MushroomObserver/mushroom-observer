# frozen_string_literal: true

# "Show this collection number" link. When `observation:` is set,
# narrows the prev/next navigation to that observation's
# collection_numbers via a scoped Query.
class Tab::CollectionNumber::Show < Tab::Base
  def initialize(collection_number:, observation: nil)
    super()
    @collection_number = collection_number
    @observation = observation
  end

  def title
    @collection_number.format_name.t
  end

  def path
    args = @collection_number.show_link_args
    return args unless @observation

    args.merge(q: Query.lookup(:CollectionNumber,
                               observations: @observation.id).q_param)
  end

  def model
    @collection_number
  end
end
