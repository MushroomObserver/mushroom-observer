# frozen_string_literal: true

require("test_helper")

module Projects
  class TargetNamesControllerTest < FunctionalTestCase
    def test_create_single_name_as_admin
      project = projects(:rare_fungi_project)
      name = names(:peltigera)
      login("rolf")

      assert_not_includes(project.target_names, name)

      post(:create, params: { project_id: project.id,
                              names: name.text_name })

      assert_includes(project.target_names.reload, name)
    end

    def test_create_multiple_names
      project = projects(:rare_fungi_project)
      login("rolf")

      input = "Peltigera\nBoletus edulis"
      post(:create, params: { project_id: project.id,
                              names: input })

      assert_includes(project.target_names.reload, names(:peltigera))
      assert_includes(project.target_names, names(:boletus_edulis))
    end

    def test_create_with_checklist_format
      project = projects(:rare_fungi_project)
      login("rolf")

      input = "Peltigera (3) *\nBoletus edulis (1)"
      post(:create, params: { project_id: project.id,
                              names: input })

      assert_includes(project.target_names.reload, names(:peltigera))
      assert_includes(project.target_names, names(:boletus_edulis))
    end

    def test_create_comma_separated
      project = projects(:rare_fungi_project)
      login("rolf")

      input = "Peltigera, Boletus edulis"
      post(:create, params: { project_id: project.id,
                              names: input })

      assert_includes(project.target_names.reload, names(:peltigera))
      assert_includes(project.target_names, names(:boletus_edulis))
    end

    def test_create_turbo_stream
      project = projects(:rare_fungi_project)
      name = names(:peltigera)
      login("rolf")

      post(:create, params: { project_id: project.id,
                              names: name.text_name,
                              format: :turbo_stream })

      assert_response(:success)
      assert_includes(project.target_names.reload, name)
    end

    def test_create_as_non_admin
      project = projects(:rare_fungi_project)
      name = names(:peltigera)
      login("mary")

      post(:create, params: { project_id: project.id,
                              names: name.text_name })

      assert_redirected_to(checklist_path(project_id: project.id))
      assert_not_includes(project.target_names.reload, name)
    end

    def test_create_with_invalid_name
      project = projects(:rare_fungi_project)
      login("rolf")

      post(:create, params: { project_id: project.id,
                              names: "Nonexistent species" })

      assert_flash_error
    end

    def test_destroy_as_admin
      project = projects(:rare_fungi_project)
      name = names(:coprinus_comatus)
      login("rolf")

      assert_includes(project.target_names, name)

      delete(:destroy, params: { project_id: project.id,
                                 id: name.id })

      assert_not_includes(project.target_names.reload, name)
    end

    def test_destroy_turbo_stream
      project = projects(:rare_fungi_project)
      name = names(:coprinus_comatus)
      login("rolf")

      delete(:destroy, params: { project_id: project.id,
                                 id: name.id,
                                 format: :turbo_stream })

      assert_response(:success)
      assert_not_includes(project.target_names.reload, name)
    end

    def test_destroy_with_invalid_name
      project = projects(:rare_fungi_project)
      login("rolf")

      delete(:destroy, params: { project_id: project.id,
                                 id: 999_999 })

      assert_flash_error
    end

    def test_destroy_as_non_admin
      project = projects(:rare_fungi_project)
      name = names(:coprinus_comatus)
      login("mary")

      delete(:destroy, params: { project_id: project.id,
                                 id: name.id })

      assert_redirected_to(checklist_path(project_id: project.id))
      assert_includes(project.target_names.reload, name)
    end
  end
end
