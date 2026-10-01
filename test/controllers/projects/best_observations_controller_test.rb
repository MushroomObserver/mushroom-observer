# frozen_string_literal: true

require("test_helper")

module Projects
  # The observation a QR code on a printed label leads to (#5416).
  class BestObservationsControllerTest < FunctionalTestCase
    setup do
      @controller = Projects::BestObservationsController.new
      @project = projects(:bolete_project)
      @name = names(:boletus_edulis)
    end

    def add_observation(image_vote: 3.0, confidence: 2.5,
                        observed_on: Date.parse("2026-09-01"))
      observation = Observation.create!(
        user: rolf, name: @name, when: observed_on,
        where: "Burbank, California, USA", vote_cache: confidence
      )
      image = Image.create!(user: rolf, when: observed_on,
                            content_type: "image/jpeg",
                            vote_cache: image_vote)
      observation.images << image
      observation.update!(thumb_image_id: image.id)
      @project.observations << observation
      observation
    end

    def show(project: @project, name: @name)
      get(:show, params: { project_id: project.id, name_id: name.id })
    end

    # The /obs/ form is the one a logged-out visitor may follow
    # (#5357), and a scan is usually logged out.
    def test_redirects_to_the_public_form_of_the_observation
      observation = add_observation

      show

      assert_redirected_to(permanent_observation_path(observation.id))
    end

    def test_no_login_needed
      observation = add_observation
      logout

      show

      assert_redirected_to(permanent_observation_path(observation.id))
    end

    # The label outlives the observation it was printed from: a
    # better photograph of the same mushroom changes where it leads.
    def test_follows_the_project_as_it_gains_a_better_photograph
      first = add_observation(image_vote: 2.0)
      show

      assert_redirected_to(permanent_observation_path(first.id))

      better = add_observation(image_vote: 4.0,
                               observed_on: Date.parse("2024-09-01"))
      show

      assert_redirected_to(permanent_observation_path(better.id))
    end

    # Nothing in the project for that name: show what it does hold
    # rather than an error, since the name may have been corrected
    # since the label was printed.
    def test_nothing_to_show_falls_back_to_the_index
      show

      assert_redirected_to(
        observations_path(project: @project.id, name: @name.text_name)
      )
      assert_flash_warning
    end

    def test_an_unknown_name
      get(:show, params: { project_id: @project.id, name_id: -1 })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
    end

    def test_an_unknown_project
      get(:show, params: { project_id: -1, name_id: @name.id })

      assert_flash_error
    end
  end
end
