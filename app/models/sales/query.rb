class Sales::Query < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects

  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
  belongs_to :user, :class_name => 'Admin::User',:foreign_key => 'created_by'

  def add_line_errors_to_header

  end

  def fill_default_header_values
    self.date_added = Time.now
  end
end
