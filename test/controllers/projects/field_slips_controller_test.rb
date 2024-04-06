# frozen_string_literal: true

require("test_helper")

module Projects
  class FieldSlipsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_new
      FieldSlipJobTracker.find_by(status: "Done")
      project = projects(:eol_project)
      params = {
        project_id: project.id
      }
      requires_login(:new, params)
      assert_template("new")
    end

    def test_create
      job_start = enqueued_jobs.size
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        commit: "Create"
      }
      post_requires_login(:create, params, katrina.login)
      assert_equal(job_start + 1, enqueued_jobs.size)
      assert_redirected_to(project_path(project.id))
    end

    def test_create_bad_project
      project = projects(:eol_project)
      job_start = enqueued_jobs.size
      project.stub(:save, false) do
        Project.stub(:safe_find, project) do
          params = {
            project_id: project.id,
            commit: "Create"
          }
          post_requires_login(:create, params, katrina.login)
          assert_equal(job_start, enqueued_jobs.size)
        end
      end
    end

    def test_create_bad_tracker
      project = projects(:eol_project)
      job_start = enqueued_jobs.size
      FieldSlipJobTracker.stub(:create, nil) do
        params = {
          project_id: project.id,
          commit: "Create"
        }
        post_requires_login(:create, params, katrina.login)
        assert_equal(job_start, enqueued_jobs.size)
      end
    end

    def test_create_non_member
      job_start = enqueued_jobs.size
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        commit: "Create"
      }
      post_requires_login(:create, params, roy.login)
      assert_equal(job_start, enqueued_jobs.size)
      assert_redirected_to(new_project_field_slip_path(project_id: project.id))
    end

    def test_create_too_many_pages
      job_start = enqueued_jobs.size
      project = projects(:eol_project)
      params = {
        project_id: project.id,
        pages: 2001,
        commit: "Create"
      }
      post_requires_login(:create, params, rolf.login)
      assert_equal(job_start, enqueued_jobs.size)
      assert_redirected_to(new_project_field_slip_path(project_id: project.id))
    end
  end
end
