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
  before_action :login_required, except: [:index, :show]
  before_action :store_location, except: :destroy
  before_action :ignore_request_unless_permitted, except: [:index, :show]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Articles.default_order # :created_at
  end

  def index_display_opts(opts, _query)
    { letters: true,
      num_per_page: 50,
      include: :user }.merge(opts)
  end

  public

  ##############################################################################

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
    @article = Article.new(
      title: params.dig(:article, :title),
      body: params.dig(:article, :body),
      user_id: @user.id
    )
    return render(:new) if flash_missing_title?

    @article.save
    redirect_to(article_path(@article.id))
  end

  def update
    @article = Article.find(params[:id])
    return render(:edit) if flash_missing_title?

    @article.title = params.dig(:article, :title)
    @article.body = params.dig(:article, :body)

    save_any_changes
    redirect_to(article_path(@article.id))
  end

  def destroy
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: :article, value: params[:id]))
    end
    redirect_to(articles_path)
  end

  private

  # Filter: Unless user permitted to perform request, just index
  def ignore_request_unless_permitted
    return if Article.can_edit?(@user)

    flash_notice(:permission_denied.t)
    redirect_to(articles_path)
  end

  # add flash message if title missing
  def flash_missing_title?
    return false if params.dig(:article, :title).present?

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
