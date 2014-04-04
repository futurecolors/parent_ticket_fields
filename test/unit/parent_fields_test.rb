require File.expand_path('../../test_helper', __FILE__)

class IssueNestedSetTest < ActiveSupport::TestCase

  def teardown
    User.current = nil
  end

  def test_parent_manual_fields_dont_get_updated_by_children
    parent = Issue.generate!(
      :priority => IssuePriority.find_by_name('Normal'),
      :done_ratio => 42,
      :start_date => '2014-03-23',
      :due_date => '2014-04-01',
      :estimated_hours => 5,
    )

    # Normally, all the fields above are automatic. Let's make some of them manual.
    Setting.plugin_parent_ticket_fields = {'priority_id' => 1, 'start_date' => 1}

    parent.generate_child!(
      :priority => IssuePriority.find_by_name('High'),
      :done_ratio => 80,
      :start_date => '2014-01-25',
      :due_date => '2014-04-15',
      :estimated_hours => 7,
    )

    parent.reload
    # Manual fields values stayed the same.
    assert_equal 'Normal', parent.priority.name
    assert_equal Date.parse('2014-03-23'), parent.start_date

    # The rest got updated according to the child.
    assert_equal 80, parent.done_ratio
    assert_equal Date.parse('2014-04-15'), parent.due_date
    assert_equal 7, parent.estimated_hours
  end

  def test_parent_manual_fields_are_editable
    parent = Issue.generate!
    User.current = parent.author
    parent.generate_child!(
      :priority => IssuePriority.find_by_name('High'),
      :done_ratio => 80,
      :start_date => '2014-01-25',
      :due_date => '2014-04-15',
      :estimated_hours => 7,
    )
    Setting.plugin_parent_ticket_fields = {'done_ratio' => 1, 'estimated_hours' => 1}
    parent.reload.safe_attributes = {
      'priority_id' => IssuePriority.find_by_name('Urgent').id,
      'done_ratio' => 1,
      'start_date' => '2014-03-20',
      'due_date' => '2014-04-25',
      'estimated_hours' => 5,
    }
    parent.save!
    parent.reload

    assert_equal 1, parent.done_ratio
    assert_equal 5, parent.estimated_hours

    assert_equal 'High', parent.priority.name
    assert_equal Date.parse('2014-01-25'), parent.start_date
    assert_equal Date.parse('2014-04-15'), parent.due_date
  end
end

class SpentTimeThresholdTest < ActiveSupport::TestCase
  def test_cannot_edit_version_if_threshold_active
    project = Project.generate!
    version1 = Version.generate!(:project => project)
    version2 = Version.generate!(:project => project)
    issue = Issue.generate!(:fixed_version_id => version1.id, :project => project)
    User.current = issue.author
    # Threshold disabled, target version is editable.
    issue.safe_attributes = {'fixed_version_id' => version2.id}
    issue.save!
    assert_equal issue.reload.fixed_version_id, version2.id

    Setting.plugin_parent_ticket_fields = {'spent_time_threshold_enabled' => 1, 'spent_time_threshold' => 2.5}
    TimeEntry.generate!(:project => project, :issue => issue, :hours => 2.1)
    # Threshold enabled but not reached, target version is editable.
    issue.safe_attributes = {'fixed_version_id' => version1.id}
    issue.save!
    assert_equal issue.reload.fixed_version_id, version1.id

    # Threshold reached, target version is not editable.
    TimeEntry.generate!(:project => project, :issue => issue, :hours => 0.5)
    issue = Issue.find issue.id # issue.total_spent_hours method is cached, we need to flush it.
    issue.safe_attributes = {'fixed_version_id' => version2.id}
    issue.save!
    assert_equal issue.reload.fixed_version_id, version1.id
  end
end
