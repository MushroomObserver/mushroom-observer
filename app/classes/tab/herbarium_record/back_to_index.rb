# frozen_string_literal: true

# "Back to herbarium_records index" link (used by the edit form when
# arriving from the index). Carries the current Query through.
class Tab::HerbariumRecord::BackToIndex < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :edit_herbarium_record_back_to_index.l
  end

  def path
    @q_param ? herbarium_records_path(q: @q_param) : herbarium_records_path
  end
end
