# frozen_string_literal: true

# Review page for a machine-read field slip. Shows the slip photo beside
# the values read off it, flags the two things worth a second look
# before anything is saved, and hands the rest to the form.
module Views::Controllers::Images::FieldSlipExtracts
  class Edit < Views::FullPageBase
    prop :extract, ::FieldSlipExtract
    prop :observation, ::Observation
    prop :user, ::User
    # Set only on the confirmation round-trip, when the reviewed ID
    # needs a Name created or disambiguated before it can be proposed.
    prop :name_feedback, _Nilable(Hash), default: nil
    prop :given_name, _Nilable(String), default: nil

    def view_template
      add_page_title(:field_slip_extract_title.t(id: @observation.id))
      container_class(:full)

      render_flags
      render_name_feedback if @name_feedback.present?
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
      render_template_mismatch
      render_code_mismatch
      render_unknown_alias
    end

    # A slip was seen, but printed on a layout this project's slips
    # don't use, so nothing was read off it. If the project should
    # accept the layout, its entry in FieldSlip::Template needs
    # updating -- then re-extract.
    def render_template_mismatch
      return unless @extract.template_mismatch?

      Alert(level: :danger) do
        trusted_html(:field_slip_extract_template_mismatch.t)
      end
    end

    def render_code_mismatch
      read, attached = @extract.code_mismatch
      return unless read

      Alert(level: :danger) do
        trusted_html(:field_slip_extract_code_mismatch.t(read: read,
                                                         attached: attached))
      end
    end

    # An abbreviation nobody has defined -- "EB2" where the project only
    # knows "2". Worth fixing at the source: the prompt is built from
    # the same alias table, so defining it improves every later slip.
    def render_unknown_alias
      written = @extract.unknown_location_alias
      return unless written

      suggestion = @extract.location_suggestion
      Alert(level: :warning) do
        if suggestion
          trusted_html(:field_slip_extract_location_guess.t(
                         written: written, suggestion: suggestion.name
                       ))
        else
          trusted_html(:field_slip_extract_unknown_alias.t(name: written))
          whitespace
          render_alias_link
        end
      end
    end

    # The attached slip's project, so the link defines the alias where
    # the slip actually lives -- `projects.first` sent it to whichever
    # other project the observation happened to be in.
    def render_alias_link
      project = @observation.field_slip&.project ||
                @observation.projects.first
      return unless project

      Link(type: :get, name: :field_slip_extract_add_alias.l,
           target: new_project_alias_path(project_id: project.id))
    end

    # The resolver's own feedback UI -- "create this name?", the
    # ambiguous-author list, the deprecated-name alternatives -- reused
    # rather than restated, so approving here behaves as it does on the
    # observation form.
    def render_name_feedback
      render(Components::Form::NameFeedback.new(
               button_name: :field_slip_extract_save.l,
               given_name: @given_name.to_s,
               names: @name_feedback[:names],
               valid_names: @name_feedback[:valid_names],
               suggest_corrections:
                 @name_feedback[:suggest_corrections].present?,
               parent_deprecated: @name_feedback[:parent_deprecated].presence
             ))
    end

    def render_slip_photo
      render(Components::InteractiveImage.new(
               image: @extract.image, user: @user, votes: false
             ))
    end

    def render_form
      render(Form.new(image: @extract.image, extract: @extract,
                      approved_name: (@given_name if @name_feedback.present?),
                      review: FormObject::FieldSlipReview.build(
                        extract: @extract, observation: @observation,
                        user: @user
                      )))
    end

    # Which setup produced these values -- the part that stays useful
    # once extraction has moved on.
    def render_provenance
      small do
        trusted_html(:field_slip_extract_provenance.t(
                       provider: @extract.provider, model: @extract.model,
                       template: @extract.template.key,
                       version: @extract.prompt_version.to_s,
                       time: @extract.updated_at.web_time
                     ))
      end
    end
  end
end
