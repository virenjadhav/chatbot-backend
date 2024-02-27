class Sales::SalesOrderShipping < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects
  include ClassMethods
  attr_accessor  :max_serial_no
  has_many :sales_order_shipments, :class_name => 'Sales::SalesOrderShipment',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :sales_order_shipping_packages, :class_name => 'Sales::SalesOrderShippingPackage',:dependent => :destroy, :extend=>ExtendAssosiation,:autosave => :true
  has_many :sales_order_shipping_truck_packages, :class_name => 'Sales::SalesOrderShippingTruckPackage',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :sales_order_shipping_attributes_values, :class_name => 'Sales::SalesOrderShippingAttributesValue',:dependent => :destroy, :extend=>ExtendAssosiation ,:autosave=>:true
  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
  #  validates_uniqueness_of :serial_no, :scope=>[:sales_order_id]
  # after_save :update_shipping_attribute_values ,on: :create

  def build_packaging_lines(lines_doc)
    lines_doc.each { |line_doc| add_line_details(line_doc)
    }
  end

  def build_attributes_values(lines_doc)
    lines_doc.each { |line_doc| add_line_details(line_doc)
    }
  end

  def add_line_details(line_doc)
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    line = shipping_packages(line_doc.name,id) ||  shipping_truck_packages(line_doc.name,id) || shipments(line_doc.name,id) || shipping_attributes_values(line_doc.name,id) ||nil
    line.apply_updated_attributes(line_doc) if line
    if line
      if line.new_record?
        self.max_serial_no = line.serial_no = (self.max_serial_no.to_i + 1).to_s
      end
      line.trans_flag = 'D' if self.trans_flag == 'D' and self.is_updated?
#      self.serial_no = self.max_serial_no.to_i + 1  if line.is_updated? and 
    end
  end

  def shipping_packages(name,id)
      sales_order_shipping_packages.find_or_build(id) if name == 'sales_order_shipping_package'
  end

  def shipping_truck_packages(name,id)
    sales_order_shipping_truck_packages.find_or_build(id) if name == 'sales_order_shipping_truck_package'
  end
  
  def shipments(name,id)
    sales_order_shipments.find_or_build(id) if name == 'sales_order_shipment'
  end

  def shipping_attributes_values(name,id)
   sales_order_shipping_attributes_values.find_or_build(id) if name == 'sales_order_shipping_attributes_value'
  end

  def save_lines
    sales_order_shipping_packages.save_updated_line
    sales_order_shipping_truck_packages.save_line
    sales_order_shipments.save_line
    sales_order_shipping_attributes_values.save_updated_line
  end
  
  def add_line_errors_to_header
    add_line_item_errors(sales_order_shipping_packages) if sales_order_shipping_packages
    add_line_item_errors(sales_order_shipping_truck_packages) if sales_order_shipping_truck_packages
    add_line_item_errors(sales_order_shipments) if sales_order_shipments
    add_line_item_errors(sales_order_shipping_attributes_values) if sales_order_shipping_attributes_values
  end

  def fill_default_detail_values
    self.current_ship_amt = self.ship_amt
    if self.is_customer_packing_slip == 'Y' && !self.customer_packing_slip_file_name.blank?
      schema_name = ActiveRecord::Base.connection.current_database.upcase
      path = Setup::Type.where("type_cd = ? and subtype_cd = ?",'UPLOAD_FOLDER','ATTACHMENT').first
      if path 
        directory = path.value + "#{schema_name}"
      end 
      self.customer_packing_slip_file_path = File.join(directory, self.customer_packing_slip_file_name)
    else
      self.customer_packing_slip_file_path = ''
    end
  end
  ## function which fires email with attachment whenever ship date is changed currently not in use but if we want to send multiple ship date
  ## change alert then uncomment the the calling part in sales_order.rb. currently we r sending only single alert even if multiple ship date changes.
  def check_ship_date_change(shipping_order_line,line_doc,order,schema_name,url_with_port)
    ship_date =  parse_xml(line_doc/'ship_date') if (line_doc/'ship_date').first
    if !shipping_order_line.new_record? and (shipping_order_line.ship_date and (shipping_order_line.ship_date.to_date.strftime("%Y-%m-%d 00:00:00") != ship_date.to_date.strftime("%Y-%m-%d 00:00:00")))
      pdf_file_name_path = Shipping::PrawnFormats::ShipDateAlert.generate_ship_date_alert(order.id,shipping_order_line.id,schema_name,shipping_order_line.internal_ship_date)
      email = Email::Email.send_email('SHIPDATEALERT',order)
      email.attachment_file = pdf_file_name_path
      email.save!
      activity = order.create_sales_order_transaction_activity("SHIP DATE CHANGED FROM #{shipping_order_line.internal_ship_date.to_date.strftime("%m/%d/%Y")} TO #{ship_date.to_date.strftime("%m/%d/%Y")}")
      activity.save!
    end
  end

#def update_shipping_attribute_values
#    self.sales_order_shipping_attributes_values.each{|item_attribute|
#     item_attribute.update_attributes(:sales_order_id => self.sales_order_id) if item_attribute.sales_order_id.to_s == ''  
#    }
#end

end
