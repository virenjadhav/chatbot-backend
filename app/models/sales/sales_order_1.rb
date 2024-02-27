class Sales::SalesOrder < ActiveRecord::Base
  # include UserStamp
  # include Dbobject
  # include General

  attr_accessor  :hour_count ## used for sending hourly mail reminders for rush orders
  attr_accessor  :max_serial_no ,:updated_order_user
  attr_accessor  :customer_email
  attr_accessor  :forward_from_mail
  attr_accessor  :forward_message
  attr_accessor :schema_name, :url_with_port
  #  has_many :customer_payment_transactions, :class_name => 'Payment::CustomerPaymentTransaction',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_card_transactions, :class_name => 'CustomerCardTransaction::CustomerCardTransaction',:foreign_key => :ref_trans_id,:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :sales_order_artworks, :class_name => 'Sales::SalesOrderArtwork' , :extend=>ExtendAssosiation
  has_many :sales_order_lines, :class_name => 'Sales::SalesOrderLine' , :extend=>ExtendAssosiation
  has_many :queries, :class_name => 'Sales::Query' , :extend=>ExtendAssosiation
  # has_many :sales_order_shippings, :class_name => 'Sales::SalesOrderShipping' , :extend=>ExtendAssosiation
  has_many :sales_order_attributes_values, :class_name => 'Sales::SalesOrderAttributesValue' , :extend=>ExtendAssosiation
  has_many :sales_order_transaction_activities, :class_name =>'Sales::SalesOrderTransactionActivity', :extend=>ExtendAssosiation
  has_many :sales_order_threads, :class_name =>'Sales::SalesOrderThread', :extend=>ExtendAssosiation
  has_many :sales_order_purchases, :class_name =>'Sales::SalesOrderPurchase', :extend=>ExtendAssosiation
  has_many :sales_order_locations, :class_name =>'Sales::SalesOrderLocation', :extend=>ExtendAssosiation
  belongs_to :company, :class_name => 'Setup::Company'
  # belongs_to :customer, :class_name => 'Customer::Customer'
  # belongs_to :vendor, :class_name => 'Vendor::Vendor'
  # belongs_to :digitizing_vendor, :class_name => 'Vendor::Vendor',:foreign_key => :digitizing_vendor_id
  
  #following three line with uniqueness is commented  for testing purpose need to be uncomment
  validates_uniqueness_of :trans_no, :scope => [:trans_bk, :trans_no, :trans_date, :company_id] , :on => :create
  # Performance Tuning
  #  validates_uniqueness_of :barcode, :scope => [:trans_bk, :trans_no, :trans_date, :company_id]
  validates_uniqueness_of :ext_ref_no, :scope => [:customer_id,:ordercancelstatus_flag], :message=>"Customer PO# Already Exists." ,:if => :is_ext_ref_no_updated?
  #  validates_existence_of :customer, :message=>'not exist'

  # Performance Tuning validate commented as done at front end
  #validates :customer,:trans_bk, :trans_no, :trans_date, :customer_id, :account_period_code,:presence => true,:on => :create
  validates :account_period_code,:presence => true,:on => :create
  #Performance Tuning validation commented as done at front end
  #validates_numericality_of :item_qty,:item_amt, :tax_amt, :discount_amt, :net_amt, :allow_nil=>false, :less_than_or_equal_to=>999999999.99, :default=>0
  # Performance Tuning commented as done at front end
  #validates_numericality_of :discount_per,:allow_nil=>false, :less_than_or_equal_to=>9999.99, :default=>0.00
  # after_commit :update_daily_production_capacity
  
  def is_ext_ref_no_updated?
    if self.ext_ref_no != self.ext_ref_no_was
      true
    else
      false
    end
  end

  def generate_trans_no(docu_type)
    self.trans_no = Setup::Sequence.generate_docu_no(self.trans_bk,docu_type,self.class,self.company_id)
  end

  #  def generate_barcode(docu_type)
  #    self.barcode = Setup::Sequence.generate_docu_no('BR01',docu_type,self.class,self.company_id)
  #  end

  after_create do
    Setup::Sequence.upd_book_code(self.trans_bk,'SAOIOD',self.trans_no,self.company_id)  if self.trans_bk == 'SO01'
    #Crmb::CrmbTaskCrud.create_task_from_order(self) if ( (self.trans_type == 'P' || self.trans_type == 'V') && !self.crmb_prospect_code.blank?)
    Crmb::CrmbTaskCrud.create_task_from_order(self) if (self.trans_type == 'V')
     
    #Performance Tuning  as the trans_no and barcode is same.
    #    Setup::Sequence.upd_book_code('BR01','BARCOD',self.barcode,self.company_id)  if self.trans_bk == 'SO01'
  end  

 def update_daily_production_capacity
    is_order_cancelled = Production::DailyProductionCapacityLib.is_order_cancelled(self)
    if is_order_cancelled
      Production::DailyProductionCapacityLib.update_production_capacity_for_revert_stages(self)
    else
      update_production_capacity_flag = Production::DailyProductionCapacityLib.update_production_capacity_flag(self)
      revert_order_stage_flag = Production::DailyProductionCapacityLib.fetch_order_stage_revert_flag(self)
      if revert_order_stage_flag
        Production::DailyProductionCapacityLib.update_production_capacity_for_revert_stages(self)
      elsif update_production_capacity_flag
        Production::DailyProductionCapacityLib.update_production_capacity(self) 
      end  
    end  
  end

  def add_line_details(line_doc)
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    is_updated_value =  parse_xml(line_doc/'is_updated') if (line_doc/'is_updated').first
    line = orderlines(line_doc.name,id) || shipping_lines(line_doc.name,id,is_updated_value) || attribute_lines(line_doc.name,id) || artwork_lines(line_doc.name,id) || order_queries(line_doc.name,id) || order_threads(line_doc.name,id) || order_purchases(line_doc.name,id) || order_locations(line_doc.name,id) || nil
    ## currently not in use check sales_order_shipping.rb for reference and before uncommenting check sales order crud another date function is calling from there.
    #    ship_date =  parse_xml(line_doc/'ship_date') if (line_doc/'ship_date').first
    #    line.check_ship_date_change(line,line_doc,self,self.schema_name,self.url_with_port) if (line_doc.name == 'sales_order_shipping' and ship_date != nil and ship_date != '')
    #    line.apply_attributes(line_doc) if line
    line.apply_updated_attributes(line_doc) if line
    if line
      if line.is_updated?
        line.fill_default_detail_values if (line_doc.name == 'sales_order_line' || line_doc.name == 'sales_order_artwork' || line_doc.name == 'sales_order_shipping')
        if (line.trans_flag == 'D' and line_doc.name == 'sales_order_line')
          line.item_qty = 0
          line.item_price = 0
          line.net_amt = 0
        end
        if line.new_record? 
          self.max_serial_no = line.serial_no = (self.max_serial_no.to_i + 1).to_s
        end
      end
      if line_doc.name == 'sales_order_shipping' and is_updated_value == 'Y'
        line.max_serial_no = line.sales_order_shipping_packages.maximum_serial_no
        line.build_packaging_lines(line_doc/:sales_order_shipping_packages/:sales_order_shipping_package)
        line.max_serial_no = line.sales_order_shipping_attributes_values.maximum_serial_no
        line.build_attributes_values(line_doc/:sales_order_shipping_attributes_values/:sales_order_shipping_attributes_value)
      end
      if (line_doc.name == 'sales_order_line' and (self.trans_type == TRANS_TYPE_SAMPLE_ORDER || self.trans_type == TRANS_TYPE_VIRTUAL_ORDER))
        line.build_lines(line_doc/:sales_order_attributes_values/:sales_order_attributes_value)
      end
      if (line_doc.name == 'sales_order_attributes_value' and (self.trans_type == TRANS_TYPE_REGULAR_ORDER || self.trans_type == TRANS_TYPE_REORDER || self.trans_type == TRANS_TYPE_PREPRODUCTION_ORDER))
        line.max_serial_no = line.sales_order_attributes_multiple_values.maximum_serial_no
        line.build_lines(line_doc/:sales_order_attributes_multiple_values/:sales_order_attributes_multiple_value)
      end
    end
  end

  def order_threads(name,id)
    sales_order_threads.find_or_build(id) if name == 'sales_order_thread'
  end
  def order_queries(name,id)
    queries.find_or_build(id) if name == 'query'
  end
  def orderlines(name,id)
    sales_order_lines.find_or_build(id) if name == 'sales_order_line' 
  end
  # def shipping_lines(name,id,is_updated = 'Y')
  #   if is_updated == 'Y' or id.blank?
  #     sales_order_shippings.find_or_build(id) if name == 'sales_order_shipping'
  #   end
  # end
  def attribute_lines(name,id)
    sales_order_attributes_values.find_or_build(id) if name == 'sales_order_attributes_value' 
  end
  def artwork_lines(name,id)
    sales_order_artworks.find_or_build(id) if name == 'sales_order_artwork' 
  end

  def order_purchases(name,id)
    sales_order_purchases.find_or_build(id) if name == 'sales_order_purchase' 
  end

  def order_locations(name,id)
    sales_order_locations.find_or_build(id) if name == 'sales_order_location' 
  end

  def save_lines
    #    sales_order_lines.save_line
    #    sales_order_shippings.save_line 
    #    sales_order_attributes_values.save_line
    #    sales_order_artworks.save_line
    #    queries.save_line
    #    sales_order_threads.save_line
    sales_order_lines.save_updated_line
    # sales_order_shippings.save_updated_line 
    # sales_order_attributes_values.save_updated_line
    # sales_order_artworks.save_updated_line
    # queries.save_updated_line
    # sales_order_threads.save_updated_line
    # sales_order_purchases.save_updated_line
    sales_order_locations.save_updated_line
  end

  def add_line_errors_to_header
    # binding.pry
    add_line_item_errors(sales_order_lines) if sales_order_lines
    # binding.pry
    # add_line_item_errors(sales_order_shippings) if sales_order_shippings
    # # binding.pry
    # add_line_item_errors(sales_order_attributes_values) if sales_order_attributes_values
    # add_line_item_errors(sales_order_artworks) if sales_order_artworks
    # add_line_item_errors(queries) if queries
    # add_line_item_errors(sales_order_threads) if sales_order_threads
    # add_line_item_errors(sales_order_purchases) if sales_order_purchases
    # add_line_item_errors(sales_order_locations) if sales_order_locations
  end

  def fill_default_header_values
    self.order_status = NEW_ORDER
    self.acknowledgment_status = NOT_SENT
    self.artwork_status = NOT_APPLICABLE if self.trans_type == TRANS_TYPE_SAMPLE_ORDER
    self.artwork_status = WAITING_ARTWORK if self.trans_type != TRANS_TYPE_SAMPLE_ORDER and self.trans_type != TRANS_TYPE_REORDER
    self.post_flag ||= 'U' 
    self.trans_flag ||= 'A' 
    self.trans_bk = 'SO01'
    self.item_qty ||= 0.00  
    self.item_amt ||= 0.00 
    self.discount_amt ||= 0.00 
    self.net_amt ||= 0.00 
    self.tax_amt ||= 0.00 
    self.discount_per ||= 0.00
    if self.trans_type == TRANS_TYPE_REORDER
      if self.reorder_type == REORDER_TYPE1
        self.artworkreceived_flag = 'Y'
        self.artworkassigned_flag = 'Y'
        #       self.artworkassigned_at = Time.now
        self.artworkcompleted_flag = 'Y'
        #       self.artworkcompleted_at = Time.now
        self.artwork_qc_assigned_flag = 'Y'
        #       self.artwork_qc_assigned_at = Time.now
        self.artwork_qc_assignedtouser_id = self.created_by
        self.artwork_qc_assignedtouser_code = self.updated_by_code        
        self.artworkreviewed_flag = 'Y'
        #       self.artworkreviewed_at = Time.now
        self.artworkapprovedbycust_flag = ''
        self.artworksenttocust_flag = 'N' if self.paper_proof_flag == 'Y'
      elsif self.reorder_type == REORDER_TYPE2
        self.artworkreceived_flag = 'Y'
        self.artworkassigned_flag = 'Y'
        #       self.artworkassigned_at = Time.now
        self.artworkcompleted_flag = 'Y'
        #       self.artworkcompleted_at = Time.now
        self.artwork_qc_assigned_flag = 'Y'
        #       self.artwork_qc_assigned_at = Time.now
        self.artwork_qc_assignedtouser_id = self.created_by
        self.artwork_qc_assignedtouser_code = self.updated_by_code
        self.artworkreviewed_flag = 'Y'
        #       self.artworkreviewed_at = Time.now
        self.artworkapprovedbycust_flag = ''
        self.artworksenttocust_flag = 'N' if self.paper_proof_flag == 'Y'
      elsif self.reorder_type == REORDER_TYPE3
        self.artworkreceived_flag = 'Y'
        self.artworkassigned_flag = 'N'
        self.artworkcompleted_flag = 'N'
        self.artworkreviewed_flag = 'N'
        self.artwork_qc_assigned_flag = 'N'
        self.artwork_qc_assignedtouser_id = nil
        self.artwork_qc_assignedtouser_code = ''
        self.artworksenttocust_flag = 'N' if self.paper_proof_flag == 'Y'
        self.artworkapprovedbycust_flag = ''
      end
      self.artwork_status = ARTWORK_RECEIVED
    end
  end
  
  def apply_header_fields_to_lines()
    self.sales_order_lines.each{ |line|
      #      if line.new_record?
      line.trans_bk = self.trans_bk
      line.trans_no = self.trans_no
      line.trans_date = self.trans_date
      line.company_id = self.company_id
      line.account_period_code = self.account_period_code
      #      end
    }
    self.sales_order_artworks.each{ |artwork|
      artwork.customer_id = self.customer_id if artwork.new_record?
      artwork.final_artwork_flag = 'Y' if self.blank_order_flag == 'Y' and artwork.artwork_version == CUSTOMER_PO
    }
    self.queries.each{ |query|
      if query.new_record?
        query.date_added = Time.now
        query.trans_no = self.trans_no
        query.trans_bk = self.trans_bk
        query.trans_date = self.trans_date
        query.company_id = self.company_id
      end
    }
  end

  def apply_line_fields_to_header()
    total_qty = 0
    total_amt = 0
    self.sales_order_lines.each{ |line|
      if line.trans_flag=='A'
        line.item_qty = 0 if !line.item_qty
        total_qty += line.item_qty if line.item_type == CATALOG
        total_amt += line.item_amt
      end
    }
    self.item_qty = total_qty
    self.net_amt = total_amt + self.ship_amt if self.ref_type == TRANS_TYPE_QUOTATION_ORDER
    # Setting Order Status based on Queries
    self.queries.each{ |query|
      if (query.answer_flag == 'N' and query.query_type == 'Order' and query.new_record?)
        self.orderpickstatus_flag = 'N'
        self.orderentrycomplete_flag = 'N'
        self.orderqcstatus_flag = 'N'
        self.order_status = ORDER_QUERIED
        self.create_sales_order_transaction_activity("ORDER QUERY NO: #{query.serial_no} IS RAISED")
      end
      if (query.answer_flag == 'N' and query.query_type == 'Artwork' and query.new_record?)
        self.artworkassigned_flag = 'N'
        self.artworkcompleted_flag = 'N'
        self.artworkreviewed_flag = 'N'
        self.artwork_qc_assigned_flag = 'N'
        self.artwork_qc_assignedtouser_id = nil
        self.artwork_qc_assignedtouser_code = ''
        self.artwork_status = ARTWORK_QUERIED
        self.create_sales_order_transaction_activity("ARTWORK QUERY NO: #{query.serial_no} IS RAISED")
      end
    }
    #Setting internal_ship_date as the min ship_date from shipping lines
    #order.ship_date = order.sales_order_shippings.inject(order.sales_order_shippings[0].internal_ship_date){|min_ship_date,x|min_ship_date = x.internal_ship_date if x.internal_ship_date < min_ship_date.to_datetime} if order.sales_order_shippings

    #    Below code commented on 23/6/15 by pradeep. Reason: sets wrong ship date on header if old ship line has minimum ship date
    #    if self.sales_order_shippings[0]
    #      min_ship_date = self.sales_order_shippings[0].internal_ship_date ; ship_method = ''
    #      self.sales_order_shippings.each {|sales_order_shipping|
    ##               if sales_order_shipping.internal_ship_date < min_ship_date
    #       if sales_order_shipping.internal_ship_date.to_date < min_ship_date.to_date and sales_order_shipping.trans_flag == 'A' # changes done by pradeep (this condition is to add to avoid wrong update of sales_orders table)
    #          min_ship_date = sales_order_shipping.internal_ship_date
    #          ship_method = sales_order_shipping.ship_method
    #        end
    #      }
    #    end

    if (self.trans_type == TRANS_TYPE_PREPRODUCTION_ORDER and self.approve_spec_order_flag != 'Y')
      sales_order_shippings = self.sales_order_shippings.select{|shipping| shipping.trans_flag == 'A' and shipping.pre_prod_flag == 'Y'}
    else
      sales_order_shippings = self.sales_order_shippings.select{|shipping| shipping.trans_flag == 'A' and shipping.pre_prod_flag != 'Y'}
    end
    if sales_order_shippings[0]
      min_ship_date = sales_order_shippings[0].internal_ship_date ; ship_method = ''
      sales_order_shippings.each {|sales_order_shipping|
        if sales_order_shipping.internal_ship_date.to_date < min_ship_date.to_date
          min_ship_date = sales_order_shipping.internal_ship_date
          ship_method = sales_order_shipping.ship_method
        end
      }
      self.ship_date = min_ship_date
      self.ship_method = ship_method
    end
  end

  def create_sales_order_transaction_activity(sales_order_stage_code, duration = '')
    #    sales_order = Sales::SalesOrder.find_by_trans_no(self.trans_no)
    #    activity = Sales::SalesOrderTransactionActivity.find_or_initialize_by_sales_order_id_and_sales_order_stage_code(:sales_order_id => sales_order.id,:sales_order_stage_code => sales_order_stage_code)
    activity = self.sales_order_transaction_activities.build
    activity.company_id = self.company_id
    activity.trans_no = self.trans_no
    activity.trans_bk = self.trans_bk
    activity.sales_order_stage_code = sales_order_stage_code
    #    activity.sales_order_id = sales_order.id
    activity.trans_date = self.trans_date
    #    activity.updated_by = self.updated_by || self.created_by
    #    #activity.created_by = self.created_by
    #    activity.created_by = self.updated_by || self.created_by

    # activity.updated_by = Admin::User.current_user#self.updated_order_user || self.updated_by || self.created_by
    activity.updated_by = 'ADMIN'#self.updated_order_user || self.updated_by || self.created_by
    activity.created_by =  self.updated_order_user ||  self.created_by
    activity.created_at = self.created_at
    activity.updated_at = self.updated_at
    activity.update_flag = self.update_flag
    activity.trans_flag = self.trans_flag
    activity.activity_date = Time.now
    activity.remarks = self.remarks
    if sales_order_stage_code.include? "'"   #to avoid error if ' present in sales_order_stage_code 
      sales_order_stage_code1 = sales_order_stage_code.gsub("'","''''")
    end
    stage_master_seq_no = Sales::SalesOrder.find_by_sql("select * from order_master_stages where stage_code = '#{sales_order_stage_code1}'")
    activity.sequence_no = stage_master_seq_no[0].sequence_no if stage_master_seq_no[0]
    activity.sequence_no = 100 if !stage_master_seq_no[0]
    activity.user_id = Admin::User.current_user #self.updated_order_user || self.updated_by || self.created_by
    activity.user_id = 1 #self.updated_order_user || self.updated_by || self.created_by
    activity.duration = duration unless duration.blank?
    return activity
  end
  
  def self.update_to_view_only(trans_bk,trans_no,company_id)
    order = self.find_by_trans_bk_and_trans_no_and_company_id(trans_bk,trans_no,company_id)
    order.update_attributes(:update_flag=>'V') if order
  end

end
