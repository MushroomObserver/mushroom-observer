# frozen_string_literal: true

require("test_helper")

module Tab::Sequence
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @sequence = sequences(:deposited_sequence)
      @observation = @sequence.observation
    end

    def test_show_without_observation
      tab = Tab::Sequence::Show.new(sequence: @sequence)

      assert_equal(@sequence.locus.truncate(@sequence.locus_width).t, tab.title)
      assert_equal(@sequence.show_link_args, tab.path)
    end

    def test_show_with_observation
      tab = Tab::Sequence::Show.new(
        sequence: @sequence, observation: @observation
      )

      assert(tab.path[:q].present?)
    end

    def test_new
      tab = Tab::Sequence::New.new(observation: @observation)

      assert_equal(:show_observation_add_sequence.t, tab.title)
      assert_equal(
        routes.new_sequence_path(observation_id: @observation.id),
        tab.path
      )
      assert_equal(Sequence, tab.model)
    end

    def test_edit
      tab = Tab::Sequence::Edit.new(
        sequence: @sequence, observation: @observation
      )

      assert_equal(:EDIT.t, tab.title)
      assert_equal(
        routes.edit_sequence_path(id: @sequence.id, back: @observation.id),
        tab.path
      )
    end

    def test_edit_and_back
      tab = Tab::Sequence::EditAndBack.new(sequence: @sequence)

      assert_equal(:edit_object.t(type: :sequence), tab.title)
      assert_equal(@sequence.edit_link_args.merge(back: :show), tab.path)
      assert_equal(@sequence, tab.model)
    end

    def test_destroy
      tab = Tab::Sequence::Destroy.new(sequence: @sequence)

      assert_equal(:destroy_object.t(type: :sequence), tab.title)
      assert_equal(@sequence, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
      assert_equal(
        routes.observation_path(@sequence.observation),
        tab.html_options[:back]
      )
      assert_equal(@sequence, tab.model)
    end

    def test_archive
      tab = Tab::Sequence::Archive.new(sequence: @sequence)

      assert_equal(:show_observation_archive_link.t, tab.title)
      assert_equal(@sequence.accession_url, tab.path)
      assert_equal("_blank", tab.html_options[:target])
      assert_equal(@sequence, tab.model)
    end

    def test_blast
      tab = Tab::Sequence::Blast.new(sequence: @sequence)

      assert_equal(:show_observation_blast_link.t, tab.title)
      assert_equal(@sequence.blast_url, tab.path)
      assert_equal("_blank", tab.html_options[:target])
      assert_equal(@sequence, tab.model)
    end
  end
end
