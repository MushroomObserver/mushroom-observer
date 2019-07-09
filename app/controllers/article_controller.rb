#  News Articles
#
#  Actions
#
#    create_article::   Create new news article
#    destroy_article::  Destroy article
#    edit_article::     Update article
#    index_article::    List selected (based on last search) articles
#    list_articles::    List all articles
#    show_article::     Show article
#
#  Callbacks and Methods
#    ignore_request_unless_permitted:: Unless user permitted to perform request,
#                       then index_articles
#    permitted?         boolean: permitted to create/update/destroy Articles
#
class ArticleController < ApplicationController
  before_action :login_required, except: [
    :index_article,
    :list_articles,
    :show_article
  ]
  before_action :store_location
  before_action :ignore_request_unless_permitted, except: [
    :index_article,
    :list_articles,
    :show_article
  ]
  helper_method :permitted?

  ##############################################################################
  #
  #  :section: Callbacks, Methods
  #
  ##############################################################################

  # Unless user permitted to perform request, just index_articles
  def ignore_request_unless_permitted
    return if permitted?

    flash_notice(:permission_denied.t)
    redirect_to(action: "index_article") and return
  end

  # permitted to create/update/destroy any Article
  def permitted?
    Article.can_edit?(@user)
  end

  ##############################################################################
  #
  #  :section: Index (multiple Articles)
  #
  ##############################################################################

  # List selected articles, based on current Query.
  def index_article
    query = find_or_create_query(:Article, by: params[:by])
    show_selected_articles(query, id: params[:id].to_s, always_index: true)
  end

  # List all articles
  def list_articles # :nologin:
    query = create_query(:Article, :all, by: :created_at)
    show_selected_articles(query)
  end

  # Show selected list of articles.
  def show_selected_articles(query, args = {})
    args = { action: :list_articles,
             letters: "articles.title",
             num_per_page: 50 }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = show_article_sorts

    show_index_of_objects(query, args)
  end

  def show_article_sorts
    [
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["user",        :sort_by_user.t],
      ["title",       :sort_by_title.t]
    ]
  end

  ##############################################################################
  #
  #  :section: Show, Create, Edit, Destroy (a single Article)
  #
  ##############################################################################

  # Display one Article
  def show_article
    return false unless (@article = find_or_goto_index(Article, params[:id]))

    @canonical_url = "#{MO.http_domain}/article/show_article/#{@article.id}"
  end

  # Create a new article
  # :norobots:
  def create_article
    return unless request.method == "POST"

    return if flash_missing_title?

    article = Article.new(title: params[:article][:title],
                          body: params[:article][:body],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id)
  end

  # add flash message if title missing
  def flash_missing_title?
    return if params[:article][:title].present?

    flash_error(:article_title_required.t)
    true
  end

  # Edit existing article
  # :norobots:
  def edit_article
    pass_query_params
    @article = find_or_goto_index(Article, params[:id])
    return unless request.method == "POST"

    return if flash_missing_title?

    @article.title = params[:article][:title]
    @article.body = params[:article][:body]
    @article.changed? ? save_edits : flash_warning(:runtime_no_changes.t)
    redirect_to(action: "show_article", id: @article.id)
  end

  def save_edits
    raise(:runtime_unable_to_save_changes.t) unless @article.save

    flash_notice(:runtime_edit_article_success.t(id: @article.id))
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
    params[:article].permit(:body, :title)
  end
end
