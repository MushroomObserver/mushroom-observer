# frozen_string_literal: true

require("test_helper")

module Admin::ExcludedInatUsers
  class ImagePurgesControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def setup
      super
      @entry = ExcludedInatUser.create!(inat_login: "listed")
      make_admin("rolf")
    end

    def test_new
      Inat::UserLookup.stub(:call, nil) do
        get(:new, params: { excluded_inat_user_id: @entry.id })
      end

      assert_response(:success)
      assert_select("#image_purge_counts li",
                    text: :image_purge_image_count.l(count: 0))
    end

    def test_create
      Inat::UserLookup.stub(:call, nil) do
        assert_enqueued_with(job: ImagePurgeJob) do
          post(:create, params: { excluded_inat_user_id: @entry.id })
        end
      end

      purge = ImagePurge.find_by(inat_login: "listed")
      assert_not_nil(purge, "Cannot find the ImagePurge")
      assert_equal(users(:rolf), purge.user)
      assert_redirected_to(admin_excluded_inat_users_path)
    end
  end
end
