#  News Articles
#
#  Actions
#
#    create_article::   Create new news article
#    index::            List all articles in inverse order of creation
#    show_article::     Display article
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
    store_location
    write_permission_denied and return unless permitted?

    return unless request.method == "POST"
    article = Article.new(name:    params[:article][:name],
                          body:    params[:article][:body],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id)
  end

  def write_permission_denied
    flash_notice(:permission_denied.t)
    redirect_to(action: "index")
  end

  def edit_article
    store_location
    write_permission_denied and return unless permitted?

    pass_query_params
    @article = find_or_goto_index(Article, params[:id].to_s)
    article_not_found unless @article
    return unless request.method == "POST"

    @article.save
    redirect_to(action: "show_article", id: article.id)
  end

  def article_not_found
    rescue RuntimeError => err
    reload_edit_name_form_on_error(err)
  end

  def reload_edit_article_form_on_error(err)
    flash_error(err.to_s) unless err.blank?
    flash_object_errors(@article)
  end

  def index
    store_location
    @articles = Article.all.order(created_at: :desc)
  end

  def show_article
    store_location
    return false unless @article = find_or_goto_index(Article, params[:id])
    @canonical_url = "#{MO.http_domain}/article/show_article/#{@article.id}"
  end

  def permitted?
    in_admin_mode?
  end

  ##############################################################################

  private

  def whitelisted_article_params
    params[:article].permit(:author, :body, :title)
  end
end
