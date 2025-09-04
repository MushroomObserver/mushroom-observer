# frozen_string_literal: true

require("test_helper")

class AddDispatchControllerTest < FunctionalTestCase
  def setup
    @user = users(:rolf)
    @project = projects(:bolete_project)
    @species_list = species_lists(:first_species_list)
    login(@user.login)
  end

  # Test login and with no parameters
  def test_requires_login
    requires_login(:new)
    assert_redirected_to(new_observation_path)
  end

  # Test basic functionality without field slip
  def test_new_without_field_slip_redirects_to_new_observation
    get(:new, params: { project: @project.id })

    expected_url = new_observation_path
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test with field slip code
  def test_new_with_field_slip_code_creates_qr_url
    field_slip_code = "ABC-123"
    get(:new, params: {
          project: @project.id,
          field_slip: field_slip_code
        })

    expected_url = "#{MO.http_domain}/qr/#{field_slip_code}"
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test field slip code with numeric prefix gets project prefix
  def test_new_with_numeric_field_slip_code_adds_project_prefix
    @project.update!(field_slip_prefix: "TEST")
    field_slip_code = "123"

    get(:new, params: {
          project: @project.id,
          field_slip: field_slip_code
        })

    expected_code = "TEST-#{field_slip_code}"
    expected_url = "#{MO.http_domain}/qr/#{expected_code}"
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test field slip code without numeric prefix doesn't get project prefix
  def test_new_with_non_numeric_field_slip_code_uses_code_as_is
    @project.update!(field_slip_prefix: "TEST")
    field_slip_code = "ABC-123"

    get(:new, params: {
          project: @project.id,
          field_slip: field_slip_code
        })

    expected_url = "#{MO.http_domain}/qr/#{field_slip_code}"
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test with species list
  def test_new_with_species_list_includes_species_list_in_params
    get(:new, params: {
          project: @project.id,
          object_type: "SpeciesList",
          object_id: @species_list.id
        })

    expected_url = new_observation_path
    expected_params = "project=#{@project.id}&species_list=#{@species_list.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test with name parameters
  def test_new_with_name_parameters_includes_them_in_params
    name = "Agaricus campestris"
    name_id = 123

    get(:new, params: {
          project: @project.id,
          name: name,
          name_id: name_id
        })

    redirect_url = response.location
    uri = URI.parse(redirect_url)
    redirect_params = CGI.parse(uri.query)

    assert_equal(new_observation_path, uri.path)
    assert_equal([@project.id.to_s], redirect_params["project"])
    assert_equal([name], redirect_params["name"])
    assert_equal([name_id.to_s], redirect_params["name_id"])
  end

  # Test with all parameters combined
  def test_new_with_all_parameters_combines_them_correctly
    field_slip_code = "XYZ-789"
    name = "Boletus edulis"
    name_id = 456

    get(:new, params: {
          project: @project.id,
          field_slip: field_slip_code,
          object_type: "SpeciesList",
          object_id: @species_list.id,
          name: name,
          name_id: name_id
        })

    redirect_url = response.location
    uri = URI.parse(redirect_url)
    redirect_params = CGI.parse(uri.query)

    assert_equal("/qr/#{field_slip_code}", uri.path)
    assert_equal([@project.id.to_s], redirect_params["project"])
    assert_equal([@species_list.id.to_s], redirect_params["species_list"])
    assert_equal([name], redirect_params["name"])
    assert_equal([name_id.to_s], redirect_params["name_id"])
  end

  # Test with blank field slip code
  def test_new_with_blank_field_slip_code_ignores_it
    get(:new, params: {
          project: @project.id,
          field_slip: "  " # whitespace only
        })

    expected_url = new_observation_path
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test with invalid species list
  def test_new_with_invalid_species_list_ignores_it
    get(:new, params: {
          project: @project.id,
          object_type: "SpeciesList",
          object_id: 999_999 # non-existent ID
        })

    expected_url = new_observation_path
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test with wrong object type
  def test_new_with_wrong_object_type_ignores_species_list
    get(:new, params: {
          project: @project.id,
          object_type: "Project", # wrong type
          object_id: @species_list.id
        })

    expected_url = new_observation_path
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test field slip code trimming
  def test_new_trims_whitespace_from_field_slip_code
    field_slip_code = "  ABC-123  "

    get(:new, params: {
          project: @project.id,
          field_slip: field_slip_code
        })

    expected_url = "#{MO.http_domain}/qr/ABC-123"
    expected_params = "project=#{@project.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test invalid project parameter
  def test_new_with_invalid_project_parameter_raises_error
    get(:new, params: { project: 999_999 })
    assert_redirected_to(new_observation_path)
  end

  # Test project implied by species_list
  def test_species_list_with_project
    spl = species_lists(:unknown_species_list)
    prefix = spl.projects.first.field_slip_prefix
    field_slip = "123"
    get(:new, params: {
          object_type: "SpeciesList",
          object_id: spl,
          field_slip:
        })

    expected_url = "#{MO.http_domain}/qr/#{prefix}-#{field_slip}"
    expected_params = "project=#{@project.id}&species_list=#{spl.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)
  end

  # Test species_list without project
  def test_species_list_without_project
    spl = species_lists(:first_species_list)
    field_slip = "123"
    get(:new, params: {
          object_type: "SpeciesList",
          object_id: spl,
          field_slip:
        })

    expected_url = new_observation_path
    expected_params = "species_list=#{spl.id}"
    expected_full_url = "#{expected_url}?#{expected_params}"

    assert_redirected_to(expected_full_url)

    assert_flash_warning(:bad_dispatch_code.t(code: field_slip))
  end
end
