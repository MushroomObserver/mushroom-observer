# encoding: utf-8
require 'test_helper'

class PivotalTest < UnitTestCase
  def test_get_stories
    if PIVOTAL_USERNAME != 'username'
      stories = Pivotal.get_stories
      assert(stories.length > 10)
      test_story = stories.select {|s| s.id == PIVOTAL_TEST_ID}.first
      assert_not_nil(test_story)
      assert_true(test_story.active?)
      assert_equal('test', test_story.name)
      assert_match(/test story/, test_story.description)
      assert_not_match(/USER|VOTE/, test_story.description)
      assert_equal(1, test_story.comments.length)
      assert_equal(3, test_story.votes.length)
      assert_equal(1, test_story.user_vote(rolf))
      assert_equal(0, test_story.user_vote(mary))
      assert_equal(1, test_story.user_vote(junk))
      assert_equal(-1, test_story.user_vote(dick))
      assert_equal(1, test_story.score)
      assert_equal(['code'], test_story.labels)
      assert_match(/test comment/, test_story.comments.first.text)
      assert_equal(mary.id, test_story.comments.first.user.id)
    end
  end

  def test_get_story
    if PIVOTAL_USERNAME != 'username'
      story = Pivotal.get_story(PIVOTAL_TEST_ID)
      assert_not_nil(story)
      assert_equal('test', story.name)
      assert_equal(1, story.comments.length)
      assert_equal(3, story.votes.length)
      assert_equal(1, story.score)
      assert_equal(-1, story.user_vote(dick))
    end
  end 

  # Instead of doing a teardown, I'm just going to throw all tests that
  # involve modifying the live(!) Pivotal server in a single test.
  def test_modifications
    if PIVOTAL_USERNAME != 'username'

      # Clean up after failed previous tests.
      stories = Pivotal.get_stories
      for story in stories.select {|s| s.name == 'temp'}
        puts "Cleaning up story ##{story.id}"
        Pivotal.delete_story(story.id)
      end

      puts "Creating temp story..."
      story = Pivotal.create_story('temp', 'this is a test', mary)
      assert_not_nil(story)
      assert_equal('feature', story.type)
      assert_equal('unscheduled', story.state)
      assert_equal(mary.id, story.user.id)
      assert_equal('temp', story.name)
      assert_equal("this is a test\n", story.description)
      assert_equal(['other'], story.labels)
      assert_equal([], story.comments)
      assert_equal([], story.votes)

      puts "Casting vote..."
      result = Pivotal.cast_vote(story.id, rolf, 1)
      assert_kind_of(Pivotal::Story, result)
      assert_equal(story.id, result.id)
      assert_equal(story.name, result.name)
      assert_equal(story.description, result.description)
      assert_equal(1, result.votes.length)
      assert_equal(1, result.score)
      assert_equal(rolf.id, result.votes.first.id)
      assert_equal(1, result.votes.first.data)

      puts "Changing vote..."
      result = Pivotal.cast_vote(story.id, rolf, -1)
      assert_kind_of(Pivotal::Story, result)
      assert_equal(story.id, result.id)
      assert_equal(story.name, result.name)
      assert_equal(story.description, result.description)
      assert_equal(1, result.votes.length)
      assert_equal(-1, result.score)

      puts "Posting comment..."
      result = Pivotal.post_comment(story.id, mary, 'test comment')
      assert_kind_of(Pivotal::Comment, result)
      assert_equal("test comment\n", result.text)
      assert_equal(mary.id, result.user.id)

      puts "Checking final result..."
      updated_story = Pivotal.get_story(story.id)
      assert_equal(story.id, updated_story.id)
      assert_equal(1, updated_story.comments.length)
      assert_equal("test comment\n", updated_story.comments.first.text)
      assert_equal(mary.id, updated_story.comments.first.user.id)

      puts "Cleaning up..."
      Pivotal.delete_story(story.id)
    end
  end
end
