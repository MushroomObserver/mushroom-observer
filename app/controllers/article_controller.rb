#  News Articles
#
#  Actions
#
#    create_article::   Create new news article
#    destroy_article::  Destroy article
#    edit_article::     Update article
#    index_article::    List all articles in inverse order of creation
#    show_article::     Show article
#
#  Methods in public interface
#
#    permitted?         boolean: permitted to create/update/destroy Articles
#
class ArticleController < ApplicationController
  ### Callbacks
  before_action :login_required, except: [
    :index_article,
    :show_article
  ]
  before_action :store_location
  before_action :ignore_request_unless_permitted, except: [
    :index_article,
    :show_article
  ]

  def ignore_request_unless_permitted
    return if permitted?
    flash_notice(:permission_denied.t)
    redirect_to(action: "index_article") and return
  end

  # permitted to create/update/destroy any Article
  def permitted?
    Article.can_edit?(@user)
  end
  helper_method :permitted?

  ### Actions and other Methods
  # Create a new article
  # :norobots:
  def create_article
    return unless request.method == "POST"
    article = Article.new(name:    params[:article][:name],
                          body:    params[:article][:body],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id)
  end

  # Edit existing article
  # :norobots:
  def edit_article
    pass_query_params
    @article = find_or_goto_index(Article, params[:id])
    return unless request.method == "POST"

    @article.name = params[:article][:name]
    @article.body = params[:article][:body]
    @article.changed? ? save_edits : flash_warning(:runtime_no_changes.t)
    redirect_to(action: "show_article", id: @article.id)
  end

  def save_edits
    if @article.save
      flash_notice(:runtime_edit_article_success.t(id: @article.id))
    else
      raise(:runtime_unable_to_save_changes.t)
    end
  end

  # List all articles in inverse order of creation
  def index_article
    @articles = Article.all.order(created_at: :desc)
    @canonical_url = "#{MO.http_domain}/article/index_article"
  end

  # Display one Article
  def show_article
    return false unless @article = find_or_goto_index(Article, params[:id])
    @canonical_url = "#{MO.http_domain}/article/show_article/#{@article.id}"
  end

  # Destroy one article
  # :norobots:
  def destroy_article
    pass_query_params
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: Article, value: params[:id]))
    end
    redirect_to(action: "index_article")
  end

  ##############################################################################

  private

  def whitelisted_article_params
    params[:article].permit(:body, :name)
  end
end
