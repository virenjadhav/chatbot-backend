class Sales::SalesOrderLine < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include General
  include ClassMethods
  attr_accessor  :max_serial_no
  has_many :sales_order_attributes_values, :class_name => 'Sales::SalesOrderAttributesValue',:dependent => :destroy, :extend=>ExtendAssosiation
  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
  belongs_to :company, :class_name => 'Setup::Company'

  # belongs_to :catalog_item, :class_name => 'Item::CatalogItem'
#following uniqueness validation is commented for testing purpose need to be uncomment
  validates_uniqueness_of :serial_no, :scope=>[:trans_no, :trans_bk, :trans_date,:company_id]
  # validates :catalog_item_id,:presence => true

  
  validates_numericality_of  :item_qty, :clear_qty, :ref_qty, :item_price, :allow_nil=>false, :default=>0
  validates_numericality_of  :discount_amt, :net_amt, :allow_nil=>false, :default=>0
  validates_numericality_of  :discount_per,:less_than_or_equal_to=>9999.99,:default=>0

  def fill_default_detail_values
    self.item_qty ||= nulltozero(self.item_qty)
    self.clear_qty ||= nulltozero(self.clear_qty)
    self.ref_qty ||= nulltozero(self.ref_qty)
    self.item_price ||= nulltozero(self.item_price)
    self.discount_per ||= nulltozero(self.discount_per)
    self.discount_amt ||= nulltozero(self.discount_amt)
    self.net_amt ||= nulltozero(self.net_amt)
    self.trans_bk = 'SO01'
  end


  def add_line_details(line_doc)
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    line = attributes_values(line_doc.name,id) ||  nil
    line.apply_attributes(line_doc) if line
    if line.new_record?
      self.max_serial_no = line.serial_no = (self.max_serial_no.to_i + 1).to_s
    end
    line.trans_flag = 'D' if self.trans_flag == 'D'
  end

  def attributes_values(name,id)
    sales_order_attributes_values.find_or_build(id) if name == 'sales_order_attributes_value'
  end
  def save_lines
    sales_order_attributes_values.save_line
  end

  def add_line_errors_to_header
    add_line_item_errors(sales_order_attributes_values) if sales_order_attributes_values
  end


end
