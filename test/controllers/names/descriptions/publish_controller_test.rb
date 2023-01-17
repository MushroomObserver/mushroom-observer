# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class PublishControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Owner can publish.
    def test_publish_draft
      publish_draft_helper(name_descriptions(:draft_coprinus_comatus), nil,
                           merged: :merged, conflict: false)
    end

    # Admin can, too.
    def test_publish_draft_admin
      publish_draft_helper(name_descriptions(:draft_coprinus_comatus), mary,
                           merged: :merged, conflict: false)
    end

    # Other members cannot.
    def test_publish_draft_member
      publish_draft_helper(name_descriptions(:draft_agaricus_campestris),
                           katrina, merged: false, conflict: false)
    end

    # Non-members certainly can't.
    def test_publish_draft_non_member
      publish_draft_helper(name_descriptions(:draft_agaricus_campestris),
                           dick, merged: false, conflict: false)
    end

    # Non-members certainly can't.
    def test_publish_draft_conflict
      draft = name_descriptions(:draft_coprinus_comatus)
      # Create a simple public description to cause conflict.
      name = draft.name
      name.description = desc = NameDescription.create!(
        name: name,
        user: rolf,
        source_type: "public",
        source_name: "",
        public: true,
        gen_desc: "Pre-existing general description."
      )
      name.save
      desc.admin_groups << UserGroup.reviewers
      desc.writer_groups << UserGroup.all_users
      desc.reader_groups << UserGroup.all_users
      # It should make the draft both public and default, "true" below tells it
      # that the default gen_desc should look like the draft's after done.  No
      # more conflicts.
      publish_draft_helper(draft.reload, nil, merged: true, conflict: false)
    end

    def publish_draft_helper(draft, user = nil, merged: true, conflict: false)
      if user
        assert_not_equal(draft.user, user)
      else
        user = draft.user
      end
      draft_gen_desc = draft.gen_desc
      name_gen_desc = begin
                        draft.name.description.gen_desc
                      rescue StandardError
                        nil
                      end
      same_gen_desc = (draft_gen_desc == name_gen_desc)
      name_id = draft.name_id
      params = {
        id: draft.id
      }
      put_requires_login(:update, params, user.login)
      name = Name.find(name_id)
      new_gen_desc = begin
                       name.description.gen_desc
                     rescue StandardError
                       nil
                     end
      if merged
        assert_equal(draft_gen_desc, new_gen_desc)
      else
        assert_equal(same_gen_desc, draft_gen_desc == new_gen_desc)
        assert(NameDescription.safe_find(draft.id))
      end
      if conflict
        assert_template("names/descriptions/edit")
        assert_template("names/descriptions/_form")
        assert(assigns(:description).gen_desc.index(draft_gen_desc))
        assert(assigns(:description).gen_desc.index(name_gen_desc))
      else
        assert_redirected_to(name_path(name_id))
      end
    end
  end
end
