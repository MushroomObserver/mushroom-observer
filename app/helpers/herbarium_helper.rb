module HerbariumHelper

  def curator_table(title, herbarium, can_delete)
    curators = herbarium.curators
    result = content_tag(:table, title_row(curators.count, title) + herbarium.curators.map {|u| curator_row(u, herbarium, can_delete)}.join.html_safe)
    result
  end

  def title_row(count, title)
    content_tag(:tr,
      content_tag(:td,
        content_tag(:b, pluralize(count, title) + ":"),
        colspan: "2"))
  end

  def curator_row(user, herbarium, can_delete)
    content_tag(:tr,
      content_tag(:td, delete_link(user, herbarium, can_delete)) +
      content_tag(:td, user_link(user, user.legal_name)))
  end

  def delete_link(user, herbarium, can_delete)
    can_delete ? link_to('X', {action: "delete_curator", id: herbarium.id,
                                user: user.id},
                              {data: { confirm: :are_you_sure.t } }) : ""
  end
end
