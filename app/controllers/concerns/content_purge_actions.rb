# frozen_string_literal: true

# Confirm and start a ContentPurge (#5521). `new` shows what the purge
# removes, which takes a few seconds for a large holder, so it is a
# separate page from the one linking to it; `create` starts the job.
# One purge per target at a time.
#
# Including controllers define:
#   purge_target  -- { target_user: } or { inat_login: }
#   purge_holder  -- whose content, for the page heading
#   purge_path    -- where `create` is posted
#   return_path   -- where to go afterwards
module ContentPurgeActions
  def new
    return refuse_second_purge if purge_in_progress

    render(Views::Controllers::ContentPurges::New.new(
             plan: ContentPurge::Plan.new(**purge_target),
             holder: purge_holder, purge_path: purge_path,
             return_path: return_path
           ))
  end

  def create
    return refuse_second_purge if purge_in_progress

    purge = ContentPurge.create!(user: @user, **purge_target)
    ContentPurgeJob.perform_later(purge)
    flash_notice(:content_purge_started.l)
    redirect_to(return_path)
  end

  private

  def purge_in_progress
    ContentPurge.in_progress_for(**purge_target)
  end

  def refuse_second_purge
    flash_error(:content_purge_in_progress.l)
    redirect_to(return_path)
  end
end
