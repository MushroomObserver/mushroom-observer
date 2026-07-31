# frozen_string_literal: true

# Review page for a machine-read field slip. Shows the slip photo beside
# the values read off it, flags the two things worth a second look
# before anything is saved, and hands the rest to the form.
module Views::Controllers::Images::FieldSlipExtracts
  class Edit < Views::FullPageBase
    prop :extract, ::FieldSlipExtract
    prop :observation, ::Observation
    prop :user, ::User

    def view_template
      add_page_title(:field_slip_extract_title.t(id: @observation.id))
      container_class(:full)

      render_flags
      Row do
        Column(xs: 12, md: 5) { render_slip_photo }
        Column(xs: 12, md: 7) { render_form }
      end
      render_provenance
    end

    private

    # The strongest signal that this image is not this observation's
    # slip: the printed code the model read is not the code attached.
    def render_flags
      render_code_mismatch
      render_unknown_alias
    end

    def render_code_mismatch
      read, attached = @extract.code_mismatch
      return unless read

      Alert(level: :danger) do
        plain(:field_slip_extract_code_mismatch.t(read: read,
                                                  attached: attached))
      end
    end

    # An abbreviation nobody has defined -- "EB2" where the project only
    # knows "2". Worth fixing at the source: the prompt is built from
    # the same alias table, so defining it improves every later slip.
    def render_unknown_alias
      written = @extract.unknown_location_alias
      return unless written

      Alert(level: :warning) do
        plain(:field_slip_extract_unknown_alias.t(name: written))
        whitespace
        render_alias_link
      end
    end

    def render_alias_link
      project = @observation.projects.first
      return unless project

      Link(type: :get, name: :field_slip_extract_add_alias.l,
           target: new_project_alias_path(project_id: project.id))
    end

    def render_slip_photo
      render(Components::InteractiveImage.new(
               image: @extract.image, user: @user, votes: false
             ))
    end

    def render_form
      render(Form.new(image: @extract.image, extract: @extract,
                      review: FormObject::FieldSlipReview.build(
                        extract: @extract, observation: @observation
                      )))
    end

    # Which setup produced these values -- the part that stays useful
    # once extraction has moved on.
    def render_provenance
      small do
        plain(:field_slip_extract_provenance.t(
                provider: @extract.provider, model: @extract.model,
                version: @extract.prompt_version.to_s,
                time: @extract.updated_at.web_time
              ))
      end
    end
  end
end
