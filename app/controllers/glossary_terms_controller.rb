# frozen_string_literal: true

# create and edit Glossary terms
class GlossaryTermsController < ApplicationController
  before_action :login_required, except: [
    :index,
    :show_past_glossary_term,
    :show
  ]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def index
    store_location
    @glossary_terms = GlossaryTerm.all.order(:name)
  end

  def show
    store_location
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
    @canonical_url = "#{MO.http_domain}/glossary/show_glossary_term/"\
                     "#{@glossary_term.id}"
    @layout = calc_layout_params
    @objects = @glossary_term.images
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @copyright_holder = @user.name
    @copyright_year = Time.now.utc.year
    @upload_license_id = @user.license_id
    @licenses = License.current_names_and_ids(@user.license)
  end

  def edit
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    glossary_term = \
      GlossaryTerm.new(user: @user, name: params[:glossary_term][:name],
                       description: params[:glossary_term][:description])
    glossary_term.add_image(process_image(image_args))
    glossary_term.save
    redirect_to(glossary_terms_path(glossary_term.id))
  end

  def update
    glossary_term = GlossaryTerm.find(params[:id].to_s)
    glossary_term.attributes = params[:glossary_term].
                               permit(:name, :description)
    glossary_term.user = @user
    glossary_term.save
    redirect_to(glossary_terms_path(glossary_term.id))
  end

  # TODO: add destroy action

  # ---------- Non-standard REST Actions ---------------------------------------

  # Show past version of GlossaryTerm.
  # Accessible only from show_glossary_term page.
  def show_past_glossary_term
    pass_query_params
    store_location
    if @glossary_term = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      if params[:version]
        @glossary_term.revert_to(params[:version].to_i)
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(glossary_term_path(@glossary_term.id))
      end
    end
  end

  # ---------- Public methods (unrouted) ---------------------------------------

  ##############################################################################

  private

  # --------- Filters


  # --------- Other private methods

  def image_args
    {
      copyright_holder: params[:copyright_holder],
      when: Time.local(params[:date][:copyright_year]).utc,
      license: License.safe_find(params[:upload][:license_id]),
      user: @user,
      image: params[:glossary_term][:upload_image]
    }
  end

  def process_image(args)
    image = nil
    name = nil
    upload = args[:image]
    if upload.blank?
      name = upload.original_filename.force_encoding("utf-8") if
        upload.respond_to?(:original_filename)

      image = Image.new(args)
      save_or_flash(image)
    end
    image
  end

  def save_or_flash(image)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      logger.error("Unable to upload image")
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_image_invalid_image.t(name: name))
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded_image.t(name: name))
    end
  end

end
