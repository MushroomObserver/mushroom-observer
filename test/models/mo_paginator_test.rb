# frozen_string_literal: true

require "test_helper"

class MOPaginatorTest < UnitTestCase
  def test_basic
    pages = MOPaginator.new

    assert_nil(pages.letter_arg)
    assert_nil(pages.number_arg)
    assert_nil(pages.page_arg)
    assert_nil(pages.letter)
    assert_equal(1,   pages.number)
    assert_equal(1,   pages.page)
    assert_equal(0,   pages.num_total)
    assert_equal(0,   pages.length)
    assert_equal(100, pages.num_per_page)
    assert_nil(pages.used_letters)

    pages.letter_arg = nil
    assert_nil(pages.letter_arg)
    pages.letter_arg = "l"
    assert_equal("l", pages.letter_arg)
    pages.letter_arg = :letter
    assert_equal(:letter, pages.letter_arg)
    pages.letter_arg = ["anything"]
    assert_equal(["anything"], pages.letter_arg)

    pages.number_arg = nil
    assert_nil(pages.number_arg)
    pages.number_arg = "l"
    assert_equal("l", pages.number_arg)
    pages.number_arg = :number
    assert_equal(:number, pages.number_arg)
    pages.number_arg = ["anything"]
    assert_equal(["anything"], pages.number_arg)

    pages.letter = nil
    assert_nil(pages.letter)
    pages.letter = 32
    assert_nil(pages.letter)
    pages.letter = " "
    assert_nil(pages.letter)
    pages.letter = "Q"
    assert_equal("Q", pages.letter)
    pages.letter = "z"
    assert_equal("Z", pages.letter)
    pages.letter = :x
    assert_equal("X", pages.letter)

    pages.page = nil
    assert_equal(1, pages.page)
    pages.page = -1
    assert_equal(1, pages.page)
    pages.page = 0
    assert_equal(1, pages.page)
    pages.page = 3
    assert_equal(3, pages.page)
    pages.page = "3"
    assert_equal(3, pages.page)
    pages.page = "letter"
    assert_equal(1, pages.page)

    pages.num_total = 0
    assert_equal(0, pages.num_total)
    pages.num_total = -1
    assert_equal(0, pages.num_total)
    pages.num_total = 10
    assert_equal(10, pages.num_total)
    pages.num_total = nil
    assert_equal(0, pages.num_total)
    pages.num_total = "str"
    assert_equal(0, pages.num_total)

    pages.num_per_page = 10
    assert_equal(10, pages.num_per_page)
    assert_raises(RuntimeError) { pages.num_per_page = nil }
    assert_raises(RuntimeError) { pages.num_per_page = -1 }
    assert_raises(RuntimeError) { pages.num_per_page = 0 }
    assert_raises(RuntimeError) { pages.num_per_page = "str" }

    pages.used_letters = nil
    assert_nil(pages.used_letters)
    pages.used_letters = []
    assert_equal([], pages.used_letters)
    pages.used_letters = [1, 2, 3]
    assert_equal([], pages.used_letters)
    pages.used_letters = ["a", :b, :C, "D"]
    assert_equal(%w[A B C D], pages.used_letters)
    pages.used_letters = [:b, :a, :b, :a, 1]
    assert_equal(%w[A B], pages.used_letters)
  end

  def test_from_and_to
    pages = MOPaginator.new
    pages.num_per_page = 20

    pages.num_total = 50
    assert_equal(3, pages.num_pages)
    pages.num_total = 40
    assert_equal(2, pages.num_pages)
    pages.num_total = 41
    assert_equal(3, pages.num_pages)
    pages.num_total = 39
    assert_equal(2, pages.num_pages)
    pages.num_total = 0
    assert_equal(0, pages.num_pages)
    pages.num_total = 1
    assert_equal(1, pages.num_pages)

    pages.num_total = 100
    pages.page = 1
    assert_equal(0..19, pages.from..pages.to)
    pages.page = 1
    assert_equal(0..19, pages.from_to)
    pages.page = 2
    assert_equal(20..39, pages.from..pages.to)
    pages.page = 2
    assert_equal(20..39, pages.from_to)

    pages.show_index(0)
    assert_equal(1, pages.page)
    pages.show_index(1)
    assert_equal(1, pages.page)
    pages.show_index(19)
    assert_equal(1, pages.page)
    pages.show_index(20)
    assert_equal(2, pages.page)
    pages.show_index(39)
    assert_equal(2, pages.page)
    pages.show_index(40)
    assert_equal(3, pages.page)
  end
end
