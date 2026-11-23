# frozen_string_literal: true

require("test_helper")

# Looks up a project's iNat targets in the background, paced against
# iNat's rate limit (#5716).
class InatTargetLookupJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper
  include InatStubHelpers

  def setup
    super
    @project = projects(:rare_fungi_project)
    @inat = external_sites(:inaturalist)
    use_memory_cache
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(lambda { |request|
        name = CGI.unescape(request.uri.query.to_s[/q=([^&]*)/, 1].to_s)
        { status: 200, body: { results: [{ id: 1, name: name }] }.to_json }
      })
    stub_request(:get, inat_api_matcher("places")).
      to_return(status: 200, body: { results: [] }.to_json)
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 200, body: { total_results: 238 }.to_json)
  end

  def project_site(**args)
    ProjectExternalSite.create!(project: @project, external_site: @inat,
                                **args)
  end

  def perform
    stub_const(InatTargetLookupJob, :LOOKUP_PACE, 0) do
      InatTargetLookupJob.perform_now(@project)
    end
  end

  def saved_lookups
    Inat::ConstraintMapper.new(@project)
  end

  def stream
    Turbo::StreamsChannel.send(:stream_name_from,
                               InatTargetLookupJob.stream(@project))
  end

  def test_enqueues_on_the_inat_lookups_queue
    assert_enqueued_with(job: InatTargetLookupJob, queue: "inat_lookups") do
      InatTargetLookupJob.perform_later(@project)
    end
  end

  def test_every_target_is_looked_up_and_saved
    perform

    assert(saved_lookups.complete?, "Every target should have a lookup")
    assert_requested(:get, inat_api_matcher("taxa"),
                     times: @project.target_names.size)
  end

  def test_saved_lookups_are_not_asked_for_again
    save_inat_lookups(@project)
    WebMock.reset_executed_requests!

    perform

    assert_not_requested(:get, inat_api_matcher("taxa"))
    assert_not_requested(:get, inat_api_matcher("places"))
    assert_empty(broadcasts(stream), "Nothing changed, so nothing to show")
  end

  # What it looked up before iNat refused stays saved, and the rest is
  # looked up later rather than pressed for now.
  def test_a_refused_lookup_runs_the_job_again_later
    stub_request(:get, inat_api_matcher("taxa")).to_return(status: 429)

    perform

    assert_not(saved_lookups.complete?, "The refused targets have no lookup")
    assert_enqueued_with(job: InatTargetLookupJob, args: [@project])
  end

  # The External Sites page follows along, then gets the count.
  def test_progress_and_the_count_are_broadcast
    project_site(use_constraints: true)

    stub_const(InatTargetLookupJob, :PROGRESS_EVERY, 1) { perform }

    messages = broadcasts(stream)
    total = @project.target_names.size + @project.target_locations.size
    assert_equal(total + 2, messages.size,
                 "1 progress msg/lookup, the count, then the button's removal")
    assert_includes(messages.first, "inat_target_lookup_progress",
                    "Progress should replace the progress line")
    count = messages[-2]
    assert_includes(count, "project_site_candidates",
                    "The count should replace the candidates lines")
    assert_includes(count, "238", "The count should be the one iNat gave")
    assert_includes(messages.last, InatTargetLookupJob::LOOK_UP_BUTTON_ID,
                    "The look-up button should be removed")
  end

  # ---- look_up_later -----------------------------------------------------

  # Following the constraints is on by default, so it is no sign the
  # project wants anything looked up.
  def test_no_look_up_later_for_constraints_with_nothing_turned_on
    project_site(use_constraints: true)

    assert_no_enqueued_jobs(only: InatTargetLookupJob) do
      InatTargetLookupJob.look_up_later(@project)
    end
  end

  def test_look_up_later_for_a_site_with_imports_on
    project_site(use_constraints: true, importing: true)

    assert_enqueued_with(job: InatTargetLookupJob, args: [@project]) do
      InatTargetLookupJob.look_up_later(@project)
    end
  end

  def test_look_up_later_for_an_alerting_project
    project_site(remote_project_id: "303327")
    @project.alerts_for(users(:mary), true)

    assert_enqueued_with(job: InatTargetLookupJob, args: [@project]) do
      InatTargetLookupJob.look_up_later(@project)
    end
  end

  def test_no_look_up_later_when_nothing_reads_the_lookups
    project_site(remote_project_id: "303327")

    assert_no_enqueued_jobs(only: InatTargetLookupJob) do
      InatTargetLookupJob.look_up_later(@project)
    end
  end

  def test_no_look_up_later_without_an_inat_site
    assert_no_enqueued_jobs(only: InatTargetLookupJob) do
      InatTargetLookupJob.look_up_later(@project)
    end
  end
end
