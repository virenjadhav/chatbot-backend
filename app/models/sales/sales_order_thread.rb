class Sales::SalesOrderThread < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects

  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'


  def add_line_errors_to_header

  end
end