class Sales::SalesOrderAttributesValue < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects
  attr_accessor  :max_serial_no
  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
  belongs_to :sales_order_line, :class_name => 'Sales::SalesOrderLine'
  has_many :sales_order_attributes_multiple_values, :class_name => 'Sales::SalesOrderAttributesMultipleValue',:dependent => :destroy, :extend=>ExtendAssosiation,:autosave => true
  #  validates_uniqueness_of :serial_no, :scope=>[:sales_order_id]

  def add_line_details(line_doc)
    #    qty =  parse_xml(line_doc/'qty') if (line_doc/'qty').first
    #    if qty.to_i != 0
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    line = attributes_multiple_values(line_doc.name,id) ||  nil
    line.apply_attributes(line_doc) if line
    if line.new_record?
      self.max_serial_no = line.serial_no = (self.max_serial_no.to_i + 1).to_s
    end
    line.trans_flag = 'D' if self.trans_flag == 'D'
    #    end
  end

  def attributes_multiple_values(name,id)
    sales_order_attributes_multiple_values.find_or_build(id) if name == 'sales_order_attributes_multiple_value'
  end
  def save_lines
    sales_order_attributes_multiple_values.save_line
  end

  def add_line_errors_to_header
    add_line_item_errors(sales_order_attributes_multiple_values) if sales_order_attributes_multiple_values
  end
end
