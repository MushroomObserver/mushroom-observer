# frozen_string_literal: true

# Form object for description move/merge actions. `target_id` is
# polymorphic: a Description id for a merge, or the id of the new
# parent (Name or Location) for a move.
class FormObject::DescriptionMoveOrMerge < FormObject::Base
  attribute :target_id, :integer
  attribute :delete, :boolean, default: false

  # Display-only accessor so the Location autocompleter field (keyed
  # on :target, a Symbol Superform can resolve) has something to
  # read -- the autocompleter's hidden field is what submits
  # target_id; this value is not read server-side.
  def target
    nil
  end

  def persisted?
    false
  end
end
