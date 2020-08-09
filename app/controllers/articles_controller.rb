# frozen_string_literal: true

#  News Articles
#
#  Actions
#
#    create:           Create article from data in "new" form
#    destroy::         Destroy article
#    edit::            Display form for editing article
#    index::           List articles, filtered by current query
#    new::             Display form for new article
#    show::            Show one article
#    update::          Update article from "edit" form
#
#  Public methods      None (ideally)
#
class ArticlesController < ApplicationController
  before_action :login_required, except: [
    :index,
    :show
  ]
  before_action :store_location, except: :destroy
  before_action :pass_query_params, except: :index
  before_action :ignore_request_unless_permitted, except: [
    :index,
    :show
  ]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def index
    filter_index? ? index_filtered : index_full
  end

  def show
    return false unless (@article = find_or_goto_index(Article, params[:id]))

    @canonical_url = article_url(@article.id)
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @article = Article.new
  end

  def edit
    @article = find_or_goto_index(Article, params[:id])
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    return render(:new) if flash_missing_title?

    @article = Article.new(
      title: params[:article][:title],
      body: params[:article][:body],
      user_id: @user.id
    )
    @article.save
    redirect_to article_path(@article.id)
  end

  def update
    @article = Article.find(params[:id])
    return render(:edit) if flash_missing_title?

    @article.title = params[:article][:title]
    @article.body = params[:article][:body]

    save_any_changes
    redirect_to article_path(@article.id)
  end

  def destroy
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: Article, value: params[:id]))
    end
    redirect_to(articles_path)
  end

  # ---------- Public methods (unrouted) ---------------------------------------

  ##############################################################################

  private

  # --------- Filters

  # Filter: Unless user permitted to perform request, just index
  def ignore_request_unless_permitted
    return if helpers.permitted?(@user)

    flash_notice(:permission_denied.t)
    redirect_to(articles_path)
  end

  # --------- Other private methods

  # should index be filtered?
  def filter_index?
    params[:q] || params[:by]
  end

  def index_filtered
    query = find_or_create_query(:Article, by: params[:by])
    show_selected_articles(
      query,
      id: params[:id].to_s,
      always_index: true
    )
  end

  def index_full
    query = create_query(
      :Article,
      :all,
      by: :created_at
    )
    show_selected_articles(query)
  end

  # Show selected list of articles.
  def show_selected_articles(query, args = {})
    args = {
      action: :index,
      letters: "articles.title",
      num_per_page: 50,
      sorting_links: [["created_at",  :sort_by_created_at.t],
                      ["updated_at",  :sort_by_updated_at.t],
                      ["user",        :sort_by_user.t],
                      ["title",       :sort_by_title.t]].freeze
    }.merge(args)
    @links ||= []

    show_index_of_objects(query, args)
  end

  # add flash message if title missing
  def flash_missing_title?
    return if params[:article][:title].present?

    flash_error(:article_title_required.t)
    true
  end

  def save_any_changes
    if @article.changed?
      raise(:runtime_unable_to_save_changes.t) unless @article.save

      flash_notice(:runtime_edit_article_success.t(id: @article.id))
    else
      flash_warning(:runtime_no_changes.t)
    end
  end

  # Retained as a model for other controllers, but
  # Not needed or testable in ArticleController because
  # because it does not mass assign
  #
  # encapsulate parameters allowed to be mass assigned
  # def article_params
  #   params[:article].permit(:body, :title)
  # end
end
