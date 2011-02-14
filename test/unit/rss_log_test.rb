require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class RssLogTest < UnitTestCase

  # -------------------------------------------------------------------
  #  Test the auto-rss-log magic.  Make sure RssLog objects are being
  #  created and attached correctly, especially since we now keep a
  #  redundant rss_log_id in the owning objects.
  # -------------------------------------------------------------------

  def test_life_cycle
    User.current = @rolf

    for model in [Location, Name, Observation, SpeciesList]
      model_name = model.type_tag

      case model.name
      when 'Location'
        obj = Location.new(
          :name => 'Test Location',
          :north => 54,
          :south => 53,
          :west  => -101,
          :east  => -100,
          :high  => 100,
          :low   => 0
        )
      when 'Name'
        obj = Name.new(
          :text_name        => 'Test',
          :display_name     => '**__Test sp.__**',
          :observation_name => '**__Test sp.__**',
          :search_name      => 'Test sp.',
          :rank             => :Genus
        )
      when 'Observation'
        obj = Observation.new(
          :when    => Time.now,
          :where   => 'Anywhere',
          :name_id => 1
        )
      when 'SpeciesList'
        obj = SpeciesList.new(
          :when  => Time.now,
          :where => 'Anywhere',
          :title => 'Test List'
        )
      end

      num = 0
      assert_nil(obj.rss_log_id, "#{model}.rss_log shouldn't exist yet")
      assert_save(obj, "#{model}.save failed")
      if model == Location
        assert_not_nil(obj.rss_log_id, "#{model}.rss_log should exist now")
        assert_equal(obj.id, obj.rss_log.send("#{model.name.underscore}_id"),
                     "#{model}.rss_log ids don't match")
        assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                     "#{model}.rss_log should only have creation line:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_match(/log_#{model_name}_created/, obj.rss_log.notes,
                     "#{model}.rss_log should have creation line:\n" +
                     "<#{obj.rss_log.notes}>")
      else
        assert_nil(obj.rss_log_id, "#{model}.rss_log shouldn't exist yet")
      end

      time = obj.rss_log.modified if obj.rss_log
      obj.log(:test_message, :arg => 'val')
      if model != Location
        assert_not_nil(obj.rss_log_id, "#{model}.rss_log should exist now")
        assert_equal(obj.id, obj.rss_log.send("#{model.name.underscore}_id"),
                     "#{model}.rss_log ids don't match")
      end
      assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                   "#{model}.rss_log should have create and test lines:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_match(/test_message.*arg.*val/, obj.rss_log.notes,
                   "#{model}.rss_log should have test line:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_not_equal(time, obj.rss_log.modified,
                       "#{model}.rss_log wasn't touched")

      time = obj.rss_log.modified
      case model
      when Location
        obj.display_name = 'New Location'
      when Name
        obj.author = 'New Author'
      when Observation
        obj.notes = 'New Notes'
      when SpeciesList
        obj.title = 'New Title'
      end
      obj.save
      if model == Location
        assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                     "#{model}.rss_log should have create, test, update lines:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_match(/log_#{model_name}_updated/, obj.rss_log.notes,
                     "#{model}.rss_log should have update line:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_not_equal(time, obj.rss_log.modified,
                         "#{model}.rss_log wasn't touched")
      end

      time = obj.rss_log.modified
      obj.destroy
      assert_equal((num+=2), obj.rss_log.notes.split("\n").length,
                   "#{model}.rss_log should have create, test, update, destroy, orphan lines:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_match(/log_#{model_name}_destroyed/, obj.rss_log.notes,
                   "#{model}.rss_log should have destroy line:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_equal(time, obj.rss_log.modified,
                   "#{model}.rss_log shouldn't have been touched")
    end
  end
end
