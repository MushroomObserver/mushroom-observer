# frozen_string_literal: true

# create and edit Glossary terms
class GlossaryTermsController < ApplicationController
  before_action :login_required, except: [:index, :show]
  before_action :store_location, except: [:create, :update, :destroy]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def index
    return patterned_index if params[:pattern].present?

    index_full
  end

  def show
    return unless find_glossary_term!

    @canonical_url = glossary_term_url
    @layout = calc_layout_params
    @other_images = @glossary_term.other_images.order(vote_cache: :desc)
    @versions = @glossary_term.versions
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @glossary_term = GlossaryTerm.new
    assign_image_form_ivars
  end

  def edit
    return unless find_glossary_term!
    return unless @glossary_term.locked? && !in_admin_mode? # happy path

    flash_error(:edit_glossary_term_not_allowed.t)
    redirect_to(glossary_term_path(@glossary_term))
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    @glossary_term = GlossaryTerm.new(
      user: @user,
      name: params[:glossary_term][:name],
      description: params[:glossary_term][:description]
    )
    return reload_form("new") unless image_and_term_saves_smooth?

    redirect_to(glossary_term_path(@glossary_term.id))
  end

  def update
    return unless find_glossary_term!

    @glossary_term.attributes = params[:glossary_term].
                                permit(:name, :description)
    @glossary_term.locked = params[:glossary_term][:locked] if in_admin_mode?

    return reload_form("edit") unless @glossary_term.save

    redirect_to(glossary_term_path(@glossary_term.id))
  end

  def destroy
    return unless find_glossary_term!
    return if redirect_non_admins!

    old_images = @glossary_term.images.to_a
    if @glossary_term.destroy
      destroy_unused_images(old_images)
      flash_notice(
        :runtime_destroyed_id.t(type: :glossary_term, value: params[:id])
      )
      redirect_to(glossary_terms_path)
    else
      redirect_to(glossary_term_path(@glossary_term.id))
    end
  end

  ##############################################################################

  private

  # --------- index private methods

  def patterned_index
    pattern = params[:pattern].to_s
    # If it matches the term ID
    if pattern.match?(/^\d+$/) &&
       (glossary_term = GlossaryTerm.safe_find(pattern))
      render(:show, params: { id: glossary_term.id },
                    location: glossary_term_path(glossary_term.id)) and return
    else
      show_selected_glossary_terms(
        create_query(:GlossaryTerm, :pattern_search, pattern: pattern)
      )
    end
  end

  def index_full
    query = create_query(:GlossaryTerm, :all, by: :name)
    show_selected_glossary_terms(query)
  end

  # Show selected list of glossary_terms.
  def show_selected_glossary_terms(query, args = {})
    includes = @user ? { thumb_image: :image_votes } : :thumb_image
    args = {
      action: :index,
      letters: "glossary_terms.name",
      num_per_page: 50,
      include: includes
    }.merge(args)

    show_index_of_objects(query, args)
  end

  # --------- show, create, edit private methods

  def find_glossary_term!
    # @glossary_term = find_or_goto_index(GlossaryTerm,
    #                                     params[:id].to_s)
    @glossary_term = GlossaryTerm.show_includes.safe_find(params[:id]) ||
                     flash_error_and_goto_index(GlossaryTerm, params[:id])
  end

  def redirect_non_admins!
    return false if in_admin_mode?

    flash_warning(:permission_denied.t)
    redirect_to(glossary_term_path(@glossary_term.id))
    true
  end

  def destroy_unused_images(images)
    images.each do |image|
      image.destroy if image.reload&.all_subjects&.empty?
    end
  end

  def assign_image_form_ivars
    @copyright_holder = params.dig(:upload, :copyright_holder) || @user.name
    @copyright_year = params.dig(:upload, :copyright_year)&.to_i ||
                      Time.now.utc.year
    @licenses = License.current_names_and_ids(@user.license)
    @upload_license_id = params.dig(:upload, :license_id) || @user.license_id
  end

  def reload_form(form)
    add_glossary_term_error_messages_to_flash
    assign_image_form_ivars
    render(form)
  end

  def add_glossary_term_error_messages_to_flash
    @glossary_term.errors.messages.each_value do |val|
      # flash_error takes a string; val is an array of size 1, e.g. ["message"]
      flash_error(val.first)
    end
  end

  # Process any image together with @glossary_term,
  # returning truthy if neither fails
  # They must be processed together to correctly validate GlossaryTerm and
  # allow backing out Image if GlossaryTerm is invalid
  def image_and_term_saves_smooth?
    # If no upload file specified, only issue is the term
    return @glossary_term.save unless upload_specified?

    # return false if image processing fails
    return false unless (saved_image = process_upload(image_args))

    @glossary_term.add_image(saved_image)
    return false if @glossary_term.save # happy path

    # term failed, so clean up the orphaned (unassociated) image
    # and its flash notice ("Successfully uploaded image ...")
    saved_image.try(:destroy)
    flash_clear
    false
  end

  def upload_specified?
    params[:upload][:image]
  end

  def process_upload(args)
    return unless (upload = args[:image])

    if upload.respond_to?(:original_filename)
      upload.original_filename.force_encoding("utf-8")
    end

    image = Image.new(args)
    save_or_flash(image)
  end

  def save_or_flash(image)
    if !image.save
      flash_object_errors(image)
      nil
    elsif !image.process_image
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_image_invalid_image.t(name: name))
      flash_object_errors(image)
      nil
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded_image.t(name: name))
      image
    end
  end

  # --- Mass Assignment

  # Permit mass assignment of image arguments for testing purposes
  def image_args
    Rails.env.test? ? permit_upload_image_param : strong_upload_image_param
  end

  def strong_upload_image_param
    {
      copyright_holder: params[:upload][:copyright_holder],
      when: Time.local(params[:upload][:copyright_year]).utc,
      license: License.safe_find(params[:upload][:license_id]),
      user: @user,
      image: params[:upload][:image]
    }
  end

  # Remove "permitted: false" from this param so that model can mass assign it
  # Do this only in test environment
  def permit_upload_image_param
    args = strong_upload_image_param
    args[:image] = params[:upload][:image]
    args
  end
end
