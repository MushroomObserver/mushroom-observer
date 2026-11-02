# frozen_string_literal: true

require("test_helper")

class FormObject::NameClassificationTest < UnitTestCase
  def test_ranks_are_descending_from_domain
    assert_equal("Domain", FormObject::NameClassification::RANKS.first)
    assert_equal("Subtribe", FormObject::NameClassification::RANKS.last)
    assert_operator(FormObject::NameClassification::RANKS.size, :>, 1)
  end

  def test_one_attribute_per_rank
    obj = FormObject::NameClassification.new(rank_kingdom: "Fungi")

    assert_equal("Fungi", obj.rank_kingdom)
    assert_nil(obj.rank_domain)
  end

  def test_persisted_for_patch_submission
    assert(FormObject::NameClassification.new.persisted?)
  end
end
