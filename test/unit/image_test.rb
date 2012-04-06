# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ImageTest < UnitTestCase

  def test_votes
    img = images(:in_situ)
    assert(img.votes.blank?)
    assert(img.image_votes.empty?)
    assert_equal(0, img.num_votes)
    assert_equal(0, img.vote_cache.to_i)
    assert_nil(img.users_vote(@mary))
    assert_nil(img.users_vote(@rolf))

    img.change_vote(@mary, 2)
    img.reload
    assert_equal("#{@mary.id} 2", img.votes)
    assert_equal(1, img.num_votes)
    assert_equal(2, img.vote_cache)
    assert_equal(2, img.users_vote(@mary))
    assert_nil(img.users_vote(@rolf))
    assert_false(img.image_votes.first.anonymous)

    img.change_vote(@rolf, 4, :anon)
    img.reload
    assert(img.votes == "#{@mary.id} 2 #{@rolf.id} 4" ||
           img.votes == "#{@rolf.id} 4 #{@marg.id} 2")
    assert_equal(2, img.num_votes)
    assert_equal(3, img.vote_cache)
    assert_equal(2, img.users_vote(@mary))
    assert_equal(4, img.users_vote(@rolf))

    img.change_vote(@mary)
    img.reload
    assert_equal("#{@rolf.id} 4", img.votes)
    assert_equal(1, img.num_votes)
    assert_equal(4, img.vote_cache)
    assert_equal(4, img.users_vote(@rolf))
    assert_nil(img.users_vote(@mary))
    assert_true(img.image_votes.first.anonymous)

    img.change_vote(@rolf)
    img.reload
    assert(img.votes.blank?)
    assert_nil(img.users_vote(@mary))
    assert_nil(img.users_vote(@rolf))
  end
end
