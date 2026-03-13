# frozen_string_literal: true

class API2
  # API for Comment
  class CommentAPI < ModelAPI
    def model
      Comment
    end

    def page_length_level
      :lightweight
    end

    def high_detail_includes
      [:user]
    end

    def query_params
      @target = parse(:object, :target, limit: Comment::ALL_TYPES, help: 1)
      {
        id_in_set: parse_array(:comment, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :creator),
        types: parse_array(:enum, :type, limit: Comment::ALL_TYPE_TAGS),
        summary_has: parse(:string, :summary_has, help: 1),
        content_has: parse(:string, :content_has, help: 1),
        target: @target ? { type: @target.class.name, id: @target.id } : nil
      }
    end

    def create_params
      {
        target: parse(:object, :target, limit: Comment::ALL_TYPES),
        summary: parse(:string, :summary, limit: 100),
        comment: parse(:string, :content),
        user: @user
      }
    end

    def update_params
      {
        summary: parse(:string, :set_summary, limit: 100, not_blank: true),
        comment: parse(:string, :set_content)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:summary)) if params[:summary].blank?
      raise(MissingParameter.new(:content)) if params[:comment].blank?
      raise(MissingParameter.new(:target))  if params[:target].blank?

      must_have_view_permission!(params[:target])
    end

    def after_create(comment)
      comment.log_create
    end
  end
end
