# frozen_string_literal: true

require("test_helper")

module Account
  class ContentPurgesControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_new_shows_what_would_be_deleted
      mary = users(:mary)
      login("mary")

      plan = ContentPurge::Plan.new(target_user: mary)
      Inat::UserLookup.stub(:call, nil) do
        get(:new)

        assert_response(:success)
        assert_select("#content_purge_counts li",
                      text: :content_purge_image_count.l(
                        count: plan.image_count
                      ))
      end
      assert_select("form[action='#{account_content_purge_path}']" \
                    "[data-turbo-confirm] button",
                    text: :content_purge_confirm.l)
    end

    def test_create_starts_one_purge
      mary = users(:mary)
      login("mary")

      assert_enqueued_with(job: ContentPurgeJob) { post(:create) }

      purge = ContentPurge.find_by(target_user: mary)
      assert_not_nil(purge, "Cannot find the ContentPurge")
      assert(purge.pending?)
      assert_equal(mary, purge.user)
      assert_redirected_to(edit_account_profile_path)

      assert_no_enqueued_jobs(only: ContentPurgeJob) { post(:create) }
      assert_flash_error
      get(:new)
      assert_redirected_to(edit_account_profile_path)
    end
  end
end
