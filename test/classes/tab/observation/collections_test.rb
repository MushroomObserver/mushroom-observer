# frozen_string_literal: true

require("test_helper")

module Tab::Observation
  class CollectionsTest < UnitTestCase
    def setup
      @obs = observations(:minimal_unknown_obs)
      @name = names(:agaricus_campestris)
      @user = users(:rolf)
    end

    def test_related_name_tabs
      tabs = Tab::Observation::RelatedNameTabs.new(
        user: @user, name: @name
      ).to_a

      assert_equal(
        [Tab::Object::Show,
         Tab::Observation::OfName,
         Tab::Observation::OfLookAlikes,
         Tab::Observation::OfRelatedTaxa],
        tabs.map(&:class)
      )
    end

    def test_web_name_tabs
      tabs = Tab::Observation::WebNameTabs.new(
        user: @user, name: @name
      ).to_a

      assert_equal(
        [Tab::Name::Mycoportal,
         Tab::Name::MycobankSearch,
         Tab::Name::UserGoogleImages],
        tabs.map(&:class)
      )
    end

    def test_at_where_actions
      tabs = Tab::Observation::AtWhereActions.new(where: "Foo").to_a

      assert_equal(
        [Tab::Observation::DefineLocation,
         Tab::Observation::AssignUndefinedLocation,
         Tab::Location::Index],
        tabs.map(&:class)
      )
    end

    def test_index_actions_no_where
      stub_no_bridge = ->(*) { false }
      ::Query.stub(:related?, stub_no_bridge) do
        tabs = Tab::Observation::IndexActions.new.to_a

        # No where param → AtWhereActions tabs skipped.
        # No related-query bridges either (stubbed). Just Map +
        # AddToList + DownloadCSV + InatImport.
        assert_equal(
          [Tab::Observation::Map,
           Tab::Observation::AddToList,
           Tab::Observation::DownloadCSV,
           Tab::Observation::InatImport],
          tabs.map(&:class)
        )
      end
    end

    def test_index_actions_with_where_param
      stub_no_bridge = ->(*) { false }
      ::Query.stub(:related?, stub_no_bridge) do
        tabs = Tab::Observation::IndexActions.new(where: "Foo").to_a

        # AtWhereActions tabs prepend.
        assert_instance_of(Tab::Observation::DefineLocation, tabs.first)
        assert_includes(tabs.map(&:class),
                        Tab::Observation::AssignUndefinedLocation)
        assert_includes(tabs.map(&:class), Tab::Location::Index)
      end
    end

    def test_form_new
      tabs = Tab::Observation::FormNew.new.to_a

      assert_equal(
        [Tab::Observation::InatImport, Tab::Observation::Index],
        tabs.map(&:class)
      )
    end

    def test_form_edit
      tabs = Tab::Observation::FormEdit.new(observation: @obs).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_naming_form
      tabs = Tab::Observation::NamingForm.new(observation: @obs).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_list_actions
      tabs = Tab::Observation::ListActions.new(observation: @obs).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_images_edit
      image = images(:in_situ_image)
      tabs = Tab::Observation::ImagesEdit.new(image: image).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_images_reuse
      tabs = Tab::Observation::ImagesReuse.new(observation: @obs).to_a

      assert_equal([Tab::Object::Return, Tab::Observation::Edit],
                   tabs.map(&:class))
    end
  end
end
