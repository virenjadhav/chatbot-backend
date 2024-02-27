class Sales::SalesOrderPurchase < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects

  attr_accessor  :max_serial_no
  
  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'

  def add_line_errors_to_header

  end
end