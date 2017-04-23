# Actions for news articles
#
#  create_article:: Create new news article.
#
class ArticleController < ApplicationController
  # Callbacks
  before_action :login_required, except: [
    :index,
    :show_article
  ]

  # Create a new article
  # :norobots:
  def create_article
    raise(:create_article_not_allowed.t) unless in_admin_mode?
    return unless request.method == "POST"

    article = Article.new(author:  params[:article][:author],
                          body:    params[:article][:body],
                          name:    params[:article][:name],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id) and return
  end


  end

  def show_glossary_term # :nologin:
    store_location
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
    @canonical_url = "#{MO.http_domain}/glossary/show_glossary_term/#{@glossary_term.id}"
    @layout = calc_layout_params
    @objects = @glossary_term.images
  end

  def index # :nologin:
    store_location
    @glossary_terms = GlossaryTerm.all.order(:name)
  end

  def process_image(args)
    image = nil
    name = nil
    upload = args[:image]
    if upload.blank?
      name = upload.original_filename.force_encoding("utf-8") if
        upload.respond_to?(:original_filename)

      image = Image.new(args)
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
    image
  end

  def edit_glossary_term # :norobots:
    # Expand to any MO user,
    # but make them owned and editable only by that user or an admin
    if request.method == "POST"
      glossary_term = GlossaryTerm.find(params[:id].to_s)
      glossary_term.attributes = params[:glossary_term].
        permit(:name, :description)
      glossary_term.user = @user
      glossary_term.save
      redirect_to(action: "show_glossary_term", id: glossary_term.id)
    else
      @glossary_term = GlossaryTerm.find(params[:id].to_s)
    end
  end

  # Show past version of GlossaryTerm.
  # Accessible only from show_glossary_term page.
  def show_past_glossary_term # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @glossary_term = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      if params[:version]
        @glossary_term.revert_to(params[:version].to_i)
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(action: show_glossary_term, id: @glossary_term.id)
      end
    end
  end

  ##############################################################################

  private

  def whitelisted_article_params
    params[:article].permit(:author, :body, :title)
  end
end
