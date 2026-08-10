# frozen_string_literal: true

# Shared field-slip handling for the observation create and update actions.
#
# `update_field_slip` applies the `params[:field_code]` change to
# `@observation` and returns a status (:unchanged / :cleared / :assigned /
# :invalid). It deliberately does NOT flash errors or set `@any_errors` —
# create and update surface an invalid code differently: create warns and
# continues (the observation is already saved by the time this runs), while
# update flags `@any_errors` and re-renders the edit form so the user can
# fix the code.
module ObservationsController::FieldSlips
  private

  # After Create, a slip reviewer lands straight on the review of the
  # photographed slip: the extraction is usually already running by
  # then (the QR jobs chain it on attach -- see DetectFieldSlipQRJob),
  # and the review page shows its progress until the read is done.
  # Decode-only here -- attaching the slip is the QR jobs' business --
  # so this adds no writes to the request.
  def redirected_to_field_slip_review?
    image = field_slip_review_image
    return false unless image

    redirect_to(edit_image_field_slip_extract_path(image.id, await: 1))
    true
  end

  # The first new photo whose QR names a slip this user reviews.
  # Gated to admins of the code's own prefix project, so ordinary
  # uploads never pay for the scan or get detoured. When the
  # observation already HAS the matching slip -- created by scanning
  # or typing the code, which makes the QR jobs skip it -- the read is
  # started from here instead.
  def field_slip_review_image
    return nil unless FieldSlip::QRDecoder.available?
    return nil unless reviews_field_slips?

    @observation.images.each do |image|
      code = FieldSlip::QRDecoder.slip_code_in(image)
      next unless code && reviewable_slip_code?(code)

      start_extraction_for_linked_slip(image, code)
      return image
    end
    nil
  end

  # A slip already linked to the observation only counts when the
  # photographed code IS that slip's -- reviewing some other slip's
  # photo into this observation is never an automatic act.
  def reviewable_slip_code?(code)
    slip = @observation.field_slip
    return false if slip && slip.code != code
    return true if in_admin_mode?

    prefix = FieldSlip.prefix_for_code(code)
    project = prefix && Project.find_by(field_slip_prefix: prefix)
    project.present? && project.is_admin?(@user)
  end

  # The QR jobs only read slips they themselves attach; a slip that
  # was already linked during this create gets its read started here.
  # Never when an extract exists -- re-photographing a slip must not
  # silently re-read one somebody may have reviewed.
  def start_extraction_for_linked_slip(image, code)
    return unless @observation.field_slip&.code == code
    return if FieldSlipExtract.exists?(image_id: image.id)

    ExtractFieldSlipJob.request(image: image, user: @user)
  end

  # Most observations in a slip-prefix project eventually carry a
  # slip, and a zbar miss is silent by design (no auto-escalation to
  # the paid scan -- see #5041) -- so the person who could fix it gets
  # told, with the scan page linked. Same gates as the scan itself, so
  # this only fires when the scan actually ran and found nothing.
  def warn_no_field_slip_detected
    return unless FieldSlip::QRDecoder.available?
    return unless @observation.occurrence_id.nil?
    return unless reviews_field_slips?

    image = @observation.images.first
    return unless image
    return if @observation.projects.none? do |proj|
      proj.field_slip_prefix.present?
    end

    flash_warning(:observation_no_field_slip_detected.t(
                    url: edit_image_field_slip_extract_path(image.id)
                  ))
  end

  # Cheap gate so ordinary uploads never run the QR scan at all: only
  # admins of a project with a field-slip prefix photograph slips.
  def reviews_field_slips?
    Project.where.not(field_slip_prefix: nil).
      exists?(admin_group_id: @user.user_group_ids)
  end

  # The submitted field-slip code, normalized. Used both to apply the change
  # and to build the caller's invalid-code message.
  def field_code
    params[:field_code].to_s.strip.upcase
  end

  # The slip a code names: the persisted row when there is one, else an
  # unsaved slip whose project is derived from the code prefix (assigning
  # `code` is what runs `update_project`). Callers need the project and
  # its defaults before any slip exists — the observation form reads it
  # for the Locality default and for which projects' aliases apply.
  def field_slip_for_code(code)
    code = code.to_s.strip.upcase
    return nil if code.blank?

    existing = FieldSlip.find_by(code: code)
    return existing if existing

    slip = FieldSlip.new
    slip.current_user = @user
    slip.code = code
    slip
  end

  # A field-slip problem has to surface *before* the observation is
  # saved, so the form comes back with the user's input intact and
  # nothing has been written. Applying the slip still happens after the
  # save — linking needs a persisted observation to hang the occurrence
  # on — but by then the code is known good.
  #
  # Sets `@any_errors` like the other validators, so it slots into the
  # same block on both create and update.
  def validate_field_slip
    return unless params.key?(:field_code)

    code = field_code
    return if code.blank?

    slip = field_slip_for_code(code)
    if !slip&.valid?
      add_field_slip_error(:observation_field_slip_invalid.t(code: code))
    elsif field_slip_occurrence_full?(slip)
      add_field_slip_error(:observation_field_slip_full.t(
                             code: code, max: Occurrence::MAX_OBSERVATIONS
                           ))
    elsif field_slip_project_barred?(slip)
      bar_field_slip(slip)
    end
  end

  # The one case where an otherwise-good code can't be used: an existing
  # slip already in a project the user is neither a member of nor able to
  # join. Invariant 2 would put this observation in that project;
  # invariant 4 forbids a non-member putting it there.
  #
  # A *new* code never lands here. `FieldSlip#update_project` already
  # declines to set a project the user can't add to, so a spare slip for
  # a closed project simply comes out project-less and saves normally.
  def field_slip_project_barred?(slip)
    project = slip&.project
    return false unless project

    !project.member?(@user) && !project.can_join?(@user)
  end

  # Not an error: the observation still saves, just without the code, so
  # nothing the user typed is lost. They can ask to join and re-enter it.
  def bar_field_slip(slip)
    @field_slip_barred = true
    flash_warning(
      :observation_field_slip_project_closed.t(
        code: slip.code, title: slip.project.title,
        url: new_project_admin_request_path(project_id: slip.project.id)
      )
    )
  end

  def add_field_slip_error(message)
    @any_errors = true
    flash_error(message)
  end

  def update_field_slip
    return :unchanged unless params.key?(:field_code)
    # `bar_field_slip` already told the user why; saving the observation
    # without the code is the whole point of that branch.
    return :unchanged if @field_slip_barred

    code = field_code
    return :unchanged if code == @observation.field_slip&.code.to_s

    code.blank? ? clear_field_slip : assign_field_slip(code)
  end

  def clear_field_slip
    occ = @observation.occurrence
    return :cleared unless occ

    if occ.primary_observation_id == @observation.id
      @observation.send(:reassign_occurrence_primary, occ)
    end
    @observation.update!(occurrence: nil)
    if Occurrence.exists?(occ.id)
      occ.reload
      occ.destroy_if_incomplete!
    end
    :cleared
  end

  # Creates/reuses the field slip and links it to @observation via an
  # occurrence (Observation#field_slip= creates the occurrence). Returns
  # :invalid when the code fails FieldSlip validation, :too_many when the
  # slip's occurrence is already at capacity.
  def assign_field_slip(code)
    existed = FieldSlip.exists?(code: code)
    field_slip = FieldSlip.find_or_create_by_code(code, @user)
    return :invalid unless field_slip
    return :too_many if field_slip_occurrence_full?(field_slip)

    # Read before the assignment below, which is what creates the
    # occurrence when the slip doesn't have one yet.
    joined = field_slip.occurrence.present?
    flash_notice(:field_slip_created.t(code: field_slip.code)) unless existed
    @observation.field_slip = field_slip
    @observation.save!
    field_slip.adopt_user_from(@observation)
    sync_occurrence_after_attach(joined)
    apply_field_slip_project(field_slip)
    :assigned
  end

  # Using a slip for an open-membership project enrolls the user in it,
  # the way the field slip form has always done — that is what a printed
  # prefix means. The observation then joins the project too, unless it
  # violates the project's constraints, in which case the slip is being
  # used as a spare and neither is associated. Mirrors the slip form's
  # own `assign_project`.
  def apply_field_slip_project(field_slip)
    project = field_slip.project
    return unless project

    join_field_slip_project(project)
    return unless project.member?(@user)
    return if project.violates_constraints?(@observation)

    project.add_observation(@observation)
  end

  # `Occurrence#observation_count_within_limits` is `on: :update` for
  # Occurrence, but attaching updates the *Observation*, so the cap never
  # fires on this path and has to be checked here.
  def field_slip_occurrence_full?(field_slip)
    occ = field_slip.occurrence
    return false unless occ

    occ.observations.count >= Occurrence::MAX_OBSERVATIONS
  end

  # The occurrence-edit and field-slip forms do this bookkeeping every
  # time they attach an observation; this path did none of it.
  #
  # Logging fires only when the observation joined an occurrence that
  # already existed. For a freshly created slip the occurrence holds just
  # this observation, whose own creation entry already says everything
  # there is to say, and a second entry would double every QR-created
  # observation in the activity feed.
  def sync_occurrence_after_attach(joined)
    occ = @observation.occurrence
    return unless occ

    Occurrence.log_field_slip_added([@observation], @user) if joined
    occ.reload
    occ.recompute_has_specimen!
    occ.recalculate_consensus!(@user)
  end
end
