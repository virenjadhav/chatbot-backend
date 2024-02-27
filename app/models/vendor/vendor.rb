class Vendor::Vendor < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects
  
  belongs_to :vendor_category, :class_name => 'Vendor::VendorCategory'
  belongs_to :gl_account, :class_name => 'GeneralLedger::GlAccount'
  has_many :vendor_contacts,:class_name =>'Vendor::VendorContact',:dependent => :destroy, :extend=>ExtendAssosiation

  has_many :vendor_items,:class_name =>'Vendor::VendorItem',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :vendor_item_stock, :class_name => 'Vendor::VendorItemStock', :extend => ExtendAssosiation
  
  validates_presence_of :code,  :message => 'is blank'
  validates_uniqueness_of :code, :message=> ' is duplicate!!!' , :on => :create
  validates_length_of :code, :maximum=>25, :allow_nil=>true ,:message=> ' cannot be more than 25 chars'  
  validates_presence_of :vendor_category_id,  :message => 'is blank' 
  
  def add_line_details(line_doc)
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    line = contacts(line_doc.name,id)   || items(line_doc.name,id) || vendor_item_stocks(line_doc.name,id) || nil
    line.apply_attributes(line_doc) if line
    line
  end
  
  def contacts(name,id)
    vendor_contacts.find_or_build(id)  if name == 'vendor_contact'
  end

  def items(name,id)
    vendor_items.find_or_build(id) if name == 'vendor_item'
  end
  
  def vendor_item_stocks(name,id)
    vendor_item_stock.find_or_build(id) if name == 'vendor_item_stock' 
  end
  
  def save_lines
    vendor_contacts.save_line
    vendor_items.save_line
    vendor_item_stock.save_updated_line
  end
  
  def add_line_errors_to_header
    add_line_item_errors(vendor_contacts)if vendor_contacts
    add_line_item_errors(vendor_items) if vendor_items
    add_line_item_errors(vendor_item_stock) if vendor_item_stock
  end

end
