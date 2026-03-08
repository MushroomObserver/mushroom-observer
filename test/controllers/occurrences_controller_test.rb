# frozen_string_literal: true

require("test_helper")

class OccurrencesControllerTest < FunctionalTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs3 = observations(:detailed_unknown_obs)
  end

  # ---------- new action ----------

  def test_new_requires_login
    requires_login(:new, observation_id: @obs1.id)
    assert_response(:success)
  end

  def test_new_with_missing_observation
    login("rolf")
    get(:new, params: { observation_id: -1 })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_new_with_no_observation_id
    login("rolf")
    get(:new, params: {})
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_new_redirects_if_occurrence_exists
    login("rolf")
    occ = Occurrence.create!(user: rolf,
                             default_observation: @obs1)
    @obs1.update!(occurrence: occ)

    get(:new, params: { observation_id: @obs1.id })
    assert_redirected_to(permanent_observation_path(@obs1.id))
    assert_flash_warning
  end

  # ---------- create action ----------

  def test_create_requires_login
    post_requires_login(
      :create,
      observation_ids: [@obs1.id, @obs2.id],
      occurrence: { observation_id: @obs1.id,
                    default_observation_id: @obs1.id }
    )
  end

  def test_create_success
    login("rolf")
    assert_difference("Occurrence.count", 1) do
      post(:create, params: create_params(@obs1, [@obs1, @obs2]))
    end
    occ = Occurrence.last
    assert_equal(@obs1, occ.default_observation)
    assert_equal(2, occ.observations.count)
    assert_redirected_to(permanent_observation_path(@obs1.id))
    assert_flash_success
  end

  def test_create_with_different_default
    login("rolf")
    post(:create, params: create_params(@obs1, [@obs1, @obs2],
                                        default: @obs2))
    occ = Occurrence.last
    assert_equal(@obs2, occ.default_observation)
  end

  def test_create_needs_at_least_two
    login("rolf")
    assert_no_difference("Occurrence.count") do
      post(:create, params: create_params(@obs1, [@obs1]))
    end
    assert_redirected_to(
      new_occurrence_path(observation_id: @obs1.id)
    )
    assert_flash_error
  end

  def test_create_with_missing_source_observation
    login("rolf")
    post(:create, params: {
           observation_ids: [-1, @obs2.id],
           occurrence: { observation_id: -1,
                         default_observation_id: -1 }
         })
    assert_redirected_to(observations_path)
    assert_flash_error
  end

  def test_create_with_field_slip_conflict
    login("rolf")
    fs1 = field_slips(:field_slip_one)
    fs2 = field_slips(:field_slip_two)
    @obs1.update!(field_slip: fs1)
    @obs2.update!(field_slip: fs2)

    assert_no_difference("Occurrence.count") do
      post(:create, params: create_params(@obs1, [@obs1, @obs2]))
    end
    assert_redirected_to(
      new_occurrence_path(observation_id: @obs1.id)
    )
    assert_flash_error
  end

  # Simulate actual browser round-trip: render form, extract
  # field names from HTML, then POST matching params.
  def test_create_round_trip
    login("rolf")
    # First, render the new form
    get(:new, params: { observation_id: @obs1.id })
    assert_response(:success)
    body = @response.body

    # Extract the form action and method
    assert_match(%r{action="/occurrences"}, body,
                 "Form should POST to /occurrences")
    assert_match(/method="post"/, body,
                 "Form should use POST method")
    # Verify no nested forms (button_to inside form breaks submission)
    occ_form = body[%r{(<form[^>]*id="occurrence_form"[^>]*>.*?</form>)}m]
    nested = occ_form&.scan(/<form[^>]*>/)
    assert_equal(1, nested&.length,
                 "Form should have no nested <form> elements")

    # Now POST as the browser would with one recent obs checked
    assert_difference("Occurrence.count", 1) do
      post(:create, params: {
             observation_ids: [@obs1.id.to_s, @obs2.id.to_s],
             occurrence: {
               observation_id: @obs1.id.to_s,
               default_observation_id: @obs1.id.to_s
             }
           })
    end
    occ = Occurrence.last
    assert_equal(2, occ.observations.count)
    assert_redirected_to(permanent_observation_path(@obs1.id))
  end

  # Verify the form generates correct field names for the
  # controller to parse.
  def test_new_form_field_names
    login("rolf")
    get(:new, params: { observation_id: @obs1.id })
    assert_response(:success)
    body = @response.body
    # Source obs hidden field nested under occurrence[]
    assert_match(/name="occurrence\[observation_id\]"/, body)
    # observation_ids[] at top level
    assert_match(/name="observation_ids\[\]"/, body)
    # default_observation_id nested under occurrence[]
    assert_match(
      /name="occurrence\[default_observation_id\]"/, body
    )
  end

  def test_create_source_always_included
    login("rolf")
    # Don't include source in observation_ids — it should be added
    post(:create, params: create_params(@obs1, [@obs2]))
    occ = Occurrence.last
    assert_includes(occ.observations, @obs1)
    assert_includes(occ.observations, @obs2)
  end

  private

  # Mirrors actual Superform output: observation_id and
  # default_observation_id nested under occurrence[],
  # observation_ids[] at top level (raw input elements).
  def create_params(source, obs_list, default: source)
    {
      observation_ids: obs_list.map(&:id),
      occurrence: {
        observation_id: source.id,
        default_observation_id: default.id
      }
    }
  end
end
