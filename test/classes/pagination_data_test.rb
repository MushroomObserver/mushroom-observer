# frozen_string_literal: true

require("test_helper")

class PaginationDataTest < UnitTestCase
  def test_basic
    page_data = PaginationData.new

    assert_nil(page_data.letter_arg)
    assert_nil(page_data.number_arg)
    assert_nil(page_data.page_arg)
    assert_nil(page_data.letter)
    assert_equal(1,   page_data.number)
    assert_equal(1,   page_data.page)
    assert_equal(0,   page_data.num_total)
    assert_equal(0,   page_data.length)
    assert_equal(100, page_data.num_per_page)
    assert_nil(page_data.used_letters)

    page_data.letter_arg = nil
    assert_nil(page_data.letter_arg)
    page_data.letter_arg = "l"
    assert_equal("l", page_data.letter_arg)
    page_data.letter_arg = :letter
    assert_equal(:letter, page_data.letter_arg)
    page_data.letter_arg = ["anything"]
    assert_equal(["anything"], page_data.letter_arg)

    page_data.number_arg = nil
    assert_nil(page_data.number_arg)
    page_data.number_arg = "l"
    assert_equal("l", page_data.number_arg)
    page_data.number_arg = :number
    assert_equal(:number, page_data.number_arg)
    page_data.number_arg = ["anything"]
    assert_equal(["anything"], page_data.number_arg)

    page_data.letter = nil
    assert_nil(page_data.letter)
    page_data.letter = 32
    assert_nil(page_data.letter)
    page_data.letter = " "
    assert_nil(page_data.letter)
    page_data.letter = "Q"
    assert_equal("Q", page_data.letter)
    page_data.letter = "z"
    assert_equal("Z", page_data.letter)
    page_data.letter = :x
    assert_equal("X", page_data.letter)

    page_data.page = nil
    assert_equal(1, page_data.page)
    page_data.page = -1
    assert_equal(1, page_data.page)
    page_data.page = 0
    assert_equal(1, page_data.page)
    page_data.page = 3
    assert_equal(3, page_data.page)
    page_data.page = "3"
    assert_equal(3, page_data.page)
    page_data.page = "letter"
    assert_equal(1, page_data.page)

    page_data.num_total = 0
    assert_equal(0, page_data.num_total)
    page_data.num_total = -1
    assert_equal(0, page_data.num_total)
    page_data.num_total = 10
    assert_equal(10, page_data.num_total)
    page_data.num_total = nil
    assert_equal(0, page_data.num_total)
    page_data.num_total = "str"
    assert_equal(0, page_data.num_total)

    page_data.num_per_page = 10
    assert_equal(10, page_data.num_per_page)
    assert_raises(RuntimeError) { page_data.num_per_page = nil }
    assert_raises(RuntimeError) { page_data.num_per_page = -1 }
    assert_raises(RuntimeError) { page_data.num_per_page = 0 }
    assert_raises(RuntimeError) { page_data.num_per_page = "str" }

    page_data.used_letters = []
    assert_equal([], page_data.used_letters)
    page_data.used_letters = [1, 2, 3]
    assert_equal([], page_data.used_letters)
    page_data.used_letters = ["a", :b, :C, "D"]
    assert_equal(%w[A B C D], page_data.used_letters)
    page_data.used_letters = [:b, :a, :b, :a, 1]
    assert_equal(%w[A B], page_data.used_letters)
  end

  def test_from_and_to
    page_data = PaginationData.new
    page_data.num_per_page = 20

    page_data.num_total = 50
    assert_equal(3, page_data.num_pages)
    page_data.num_total = 40
    assert_equal(2, page_data.num_pages)
    page_data.num_total = 41
    assert_equal(3, page_data.num_pages)
    page_data.num_total = 39
    assert_equal(2, page_data.num_pages)
    page_data.num_total = 0
    assert_equal(0, page_data.num_pages)
    page_data.num_total = 1
    assert_equal(1, page_data.num_pages)

    page_data.num_total = 100
    page_data.page = 1
    assert_equal(0..19, page_data.from..page_data.to)
    page_data.page = 1
    assert_equal(0..19, page_data.from_to)
    page_data.page = 2
    assert_equal(20..39, page_data.from..page_data.to)
    page_data.page = 2
    assert_equal(20..39, page_data.from_to)

    page_data.index_at(0)
    assert_equal(1, page_data.page)
    page_data.index_at(1)
    assert_equal(1, page_data.page)
    page_data.index_at(19)
    assert_equal(1, page_data.page)
    page_data.index_at(20)
    assert_equal(2, page_data.page)
    page_data.index_at(39)
    assert_equal(2, page_data.page)
    page_data.index_at(40)
    assert_equal(3, page_data.page)
  end
end
