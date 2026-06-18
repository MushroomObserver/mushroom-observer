# frozen_string_literal: true

require "test_helper"

# Tests for the shared base class
# `Views::Controllers::Descriptions::Versions::Show`. Exercised in
# production through the two thin subclasses
# (`Names::Descriptions::Versions::Show`,
# `Locations::Descriptions::Versions::Show`), but the abstract
# extension points + the `title_permission_label` branches deserve
# direct coverage.
class Views::Controllers::Descriptions::Versions::ShowTest <
  ComponentTestCase
  # Subclass-with-all-extension-points-implemented, so we can render
  # the base view without going through a real controller path. Skips
  # `around_template` so the test renders only the action body, not the
  # full application layout (no need to stub Sidebar / TopNav /
  # current_languages for these content-shape assertions).
  class TestSubclass < ::Views::Controllers::Descriptions::Versions::Show
    def around_template
      yield
    end

    private

    def page_title_key
      :show_past_name_description_title
    end

    def version_actions
      ::Tab::NameDescription::VersionActions.new(
        description: @description, desc_title: desc_title
      )
    end
  end

  def setup
    super
    @user = users(:rolf)
    @desc = name_descriptions(:peltigera_user_desc)
  end

  # -- abstract extension points --------------------------------

  def test_page_title_key_raises_in_base_class
    base = ::Views::Controllers::Descriptions::Versions::Show.new(
      description: @desc, user: @user, versions: @desc.versions.to_a
    )

    assert_raises(NotImplementedError) do
      base.send(:page_title_key)
    end
  end

  def test_version_actions_raises_in_base_class
    base = ::Views::Controllers::Descriptions::Versions::Show.new(
      description: @desc, user: @user, versions: @desc.versions.to_a
    )

    assert_raises(NotImplementedError) do
      base.send(:version_actions)
    end
  end
  # -- title_permission_label branches --------------------------
  #
  # The label is incorporated into the page title (`:show_past_*_title`
  # i18n key) via `desc_title`, then echoed back through
  # `add_page_title`. The page-title is buffered on `content_for(
  # :title)`, but the rendered output also embeds it in the
  # `DetailsAndAltsPanel` body. Render the view and assert the
  # permission label shows up in the rendered HTML.

  def test_default_label_for_parent_default_description
    desc = make_default_description_for_parent
    view = TestSubclass.new(description: desc, user: @user,
                            versions: desc.versions.to_a)

    html = render(view)
    assert_includes(html, "(#{:default.l})")
  end

  def test_public_label_for_public_non_default_description
    desc = name_descriptions(:peltigera_alt_desc)
    skip("Need a public, non-default desc") unless
      desc.public && desc.parent.description_id != desc.id
    view = TestSubclass.new(description: desc, user: @user,
                            versions: desc.versions.to_a)

    html = render(view)
    assert_includes(html, "(#{:public.l})")
  end

  def test_restricted_label_for_reader_of_private_description
    desc = name_descriptions(:draft_coprinus_comatus)
    skip("Need a private description") if desc.public
    skip("Owner must be a reader") unless desc.is_reader?(desc.user)
    view = TestSubclass.new(description: desc, user: desc.user,
                            versions: desc.versions.to_a)

    html = render(view)
    assert_includes(html, "(#{:restricted.l})")
  end

  def test_private_label_for_non_reader_of_private_description
    desc = name_descriptions(:draft_coprinus_comatus)
    skip("Need a private description") if desc.public
    non_reader = users(:zero_user)
    skip("Need a non-reader user") if desc.is_reader?(non_reader)
    view = TestSubclass.new(description: desc, user: non_reader,
                            versions: desc.versions.to_a)

    html = render(view)
    assert_includes(html, "(#{:private.l})")
  end

  private

  def make_default_description_for_parent
    desc = name_descriptions(:peltigera_user_desc)
    desc.parent.update_column(:description_id, desc.id)
    desc
  end
end
