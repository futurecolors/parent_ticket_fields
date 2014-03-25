require_dependency 'issue'

Issue.class_eval do
  def fake_leaf?
    true
  end
  def fake_safe_attributes=(attrs, user=User.current)
    return unless attrs.is_a?(Hash)
    # Making safe_attributes setter think the current issue is a leaf (has no
    # subtasks), even if it isn't, so the setter doesn't reject any fields.
    Issue.class_eval do
      alias_method :real_leaf?, :leaf?
      alias_method :leaf?, :fake_leaf?
    end

    # Rejecting non-manual fields.
    manual_fields = (Setting.plugin_parent_ticket_fields || {}).keys
    automatic_fields = %w(priority_id done_ratio start_date due_date estimated_hours) - manual_fields
    unless real_leaf?
      attrs.reject! {|k,v| automatic_fields.include?(k)}
    end

    self.send(:real_safe_attributes=, attrs, user)
    Issue.class_eval do
      alias_method :leaf?, :real_leaf?
    end
  end

  alias_method :real_safe_attributes=, :safe_attributes=
  alias_method :safe_attributes=, :fake_safe_attributes=

  def automatic_field?(field_name)
    !leaf? && !Setting.plugin_parent_ticket_fields.include?(field_name)
  end

  def recalculate_wrapper(issue_id)
    if issue_id && p = Issue.find_by_id(issue_id)
      values = {}
      # Saving manual fields values in order to restore them later.
      (Setting.plugin_parent_ticket_fields || {}).keys.each do |field|
        values[field] = p.send(field)
      end
      real_recalculate issue_id
      if !values.empty?
        Issue.update(issue_id, values)
      end
    end
  end
  alias_method :real_recalculate, :recalculate_attributes_for
  alias_method :recalculate_attributes_for, :recalculate_wrapper
end
