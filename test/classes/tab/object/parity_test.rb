# frozen_string_literal: true

require("test_helper")

# Output-parity test for `Tabs::GeneralHelper` → `Tab::Object::*` +
# `Tab::ExternalSearch` migration. RHS InternalLink constructions
# below are byte-for-byte copies of the pre-conversion helper-method
# bodies.
module Tab::Object
  class ParityTest < UnitTestCase
    def setup
      @project = projects(:bolete_project)
    end

    def test_return_default_title
      text = :cancel_and_show.t(type: @project.type_tag)
      expected = ::InternalLink::Model.new(
        text, @project, @project.show_link_args,
        html_options: { class: "#{@project.type_tag}_return_link" }
      ).tab

      assert_equal(expected,
                   Tab::Object::Return.new(object: @project).to_a)
    end

    def test_return_title_override
      expected = ::InternalLink::Model.new(
        "Custom", @project, @project.show_link_args,
        html_options: { class: "#{@project.type_tag}_return_link" }
      ).tab

      assert_equal(
        expected,
        Tab::Object::Return.new(object: @project, title: "Custom").to_a
      )
    end

    def test_show
      text = :show_object.t(type: @project.type_tag)
      expected = ::InternalLink::Model.new(
        text, @project, @project.show_link_args,
        html_options: { class: "#{@project.type_tag}_link" }
      ).tab

      assert_equal(expected,
                   Tab::Object::Show.new(object: @project).to_a)
    end

    def test_show_parent
      desc = name_descriptions(:agaricus_campestras_desc)
      text = :show_object.t(type: desc.parent.type_tag)
      expected = ::InternalLink::Model.new(
        text, desc, desc.parent.show_link_args,
        html_options: { class: "parent_#{desc.parent.type_tag}_link" }
      ).tab

      assert_equal(expected,
                   Tab::Object::ShowParent.new(object: desc).to_a)
    end

    def test_index_no_q_param
      text = :list_objects.t(type: @project.type_tag)
      expected = ::InternalLink::Model.new(
        text, @project, @project.index_link_args,
        html_options: {
          class: "#{@project.type_tag.to_s.pluralize}_index_link"
        }
      ).tab

      assert_equal(expected,
                   Tab::Object::Index.new(object: @project).to_a)
    end

    def test_external_search_google_maps
      expected = ::InternalLink.new(
        "Google Maps", "https://maps.google.com/maps?q=Burbank",
        html_options: { id: "search_link_to_Google_Maps_Burbank" }
      ).tab

      assert_equal(
        expected,
        Tab::ExternalSearch.new(site: :Google_Maps,
                                query: "Burbank").to_a
      )
    end
  end
end
