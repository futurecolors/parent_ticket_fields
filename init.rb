require 'redmine'
require_relative 'lib/issue_patch'

Redmine::Plugin.register :parent_ticket_fields do
  name 'Parent Ticket Fields plugin'
  author 'Sergey Morozov'
  description "If a ticket has subtickets, you can't edit certain fields. This plugin
    lets you configure which fields are editable (and they won't be updated when a
    child ticket changes)."
  version '0.0.1'
  url 'https://github.com/futurecolors/parent_ticket_fields'
  author_url 'https://github.com/thesealion'
  settings :default => {}, :partial => 'parent_ticket_fields/settings'
end
