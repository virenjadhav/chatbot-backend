class Customer::Customer < ActiveRecord::Base
  require 'has_finder'
  include UserStamp
  include Dbobject
  include General
  include ClassMethods
  include GenericSelects

  attr_accessor :prospect_code

  #attr_protected :id, :updated_at, :created_at
  #  attr_accessor  :parent_code, :customer_category_code
  belongs_to :company, :class_name => 'Setup::Company'
  belongs_to :customer_category
  #  belongs_to :memo_terms ,  :class_name => "Setup::Term",
  #    :foreign_key => "memo_term_id"
  belongs_to :invoice_terms ,  :class_name => "Setup::Term",
    :foreign_key => "inv_term_id" 
                          
  belongs_to :shipping, :class_name => 'Setup::Shipping'
  belongs_to :bill_to,  :class_name => "Customer",
    :foreign_key => "billto_id"
  has_many :customer_payment_profiles, :class_name => 'Payment::CustomerPaymentProfile',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_shippings, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_notes, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_asirankings, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_salespeople, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_group_lines, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_relationships,:class_name =>'Customer::CustomerRelationship',:dependent => :destroy, :extend=>ExtendAssosiation
  #  has_many :customer_wishlists, :dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_item_pricings,:class_name =>'Customer::CustomerItemPricing',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_item_production_days,:class_name =>'Customer::CustomerItemProductionDay',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_item_harmonious_costs,:class_name =>'Customer::CustomerItemHarmoniousCost',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :customer_contacts,:class_name =>'Customer::CustomerContact',:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :discount_coupons, :class_name => 'Setup::DiscountCoupon', :extend => ExtendAssosiation
  has_many :customer_transaction_activities, :class_name => 'Customer::CustomerTransactionActivity', :extend => ExtendAssosiation
  has_many :customer_buying_group, :class_name => 'Customer::CustomerBuyingGroup', :extend => ExtendAssosiation
  belongs_to :parent_customer, :foreign_key => 'billto_id', :class_name => 'Customer::Customer'
  belongs_to :salesperson
  belongs_to :crmb_prospect, :class_name => 'Crmb::CrmbProspect', :foreign_key => "id", :primary_key => "parent_account_id"

  #  scope :activecustomer, :conditions => { :trans_flag => 'A' }
                            
  #  belongs_to :tax   -----tax table to be defined

  #  has_many :sales_orders

  validates_numericality_of  :discount_per, :less_than_or_equal_to=>999.99,:allow_nil=>true
  #  validates_numericality_of  :coop_per, :less_than_or_equal_to=>999.99,:allow_nil=>true
  validates_numericality_of  :salescomm_per, :less_than_or_equal_to=>999.99,:allow_nil=>true
  validates_numericality_of  :due_days, :less_than_or_equal_to=>99999,:allow_nil=>true
  validates_numericality_of  :return_checks, :less_than_or_equal_to=>99999,:allow_nil=>true
  validates_numericality_of  :postdated_checks, :less_than_or_equal_to=>99999,:allow_nil=>true
  validates_numericality_of  :credit_limit, :less_than_or_equal_to=>9999999999.99,:allow_nil=>true
  #  validates_numericality_of  :base_goldprice, :less_than_or_equal_to=>999.99,:allow_nil=>true
  validates_numericality_of  :impairment_percent, :less_than_or_equal_to=>999.99,:allow_nil=>true
  validates_uniqueness_of :code, :message=>" is duplicate. This Customer Code already exist!!!!" ,:on => :create
  validates_uniqueness_of :four51_duns_no, :message=>" is duplicate. This DUNS already exist!!!!" ,:allow_nil=>true,:if => :is_four51_duns_no_updated?
    #  validates_uniqueness_of :asi_number, :message=>" ASI# Already Exists." 
  validate :check_duplicate_asi_ppai_sage_dc ##this validation is commented becoz of accounting code of parent family change
 
  def is_four51_duns_no_updated?
    if (self.four51_duns_no != self.four51_duns_no_was.to_s)
      return true 
    end
  end
  
  def check_duplicate_asi_ppai_sage_dc
    unless self.asi_number.blank?
      asi_count = Customer::Customer.find_by_sql(["select count (*) as asi_total from customers where trans_flag = 'A' and asi_number = '#{self.asi_number}' and billto_id != '#{self.billto_id}' and id != '#{self.id}'"])[0]
      errors.add(' ', " ASI# Already taken by some other customer.") if asi_count.asi_total > 0
    end
    unless self.ppai.blank?
      ppai_count  = Customer::Customer.find_by_sql(["select count (*) as ppai_total from customers where trans_flag = 'A' and ppai = '#{self.ppai}' and billto_id != '#{self.billto_id}' and id != '#{self.id}'"])[0]
      errors.add(' ', "PPAI# Already taken by some other customer.") if ppai_count.ppai_total > 0
    end
    unless self.sage.blank?
      sage_count  = Customer::Customer.find_by_sql(["select count (*) as sage_total from customers where trans_flag = 'A' and sage = '#{self.sage}' and billto_id != '#{self.billto_id}' and id != '#{self.id}'"])[0]
      errors.add(' ', "SAGE# Already taken by some other customer.") if sage_count.sage_total > 0
    end
    unless self.dc.blank?
      dc_count  = Customer::Customer.find_by_sql(["select count (*) as dc_total from customers where trans_flag = 'A' and dc = '#{self.dc}' and billto_id != '#{self.billto_id}' and id != '#{self.id}'"])[0]
      errors.add(' ', "DC# Already taken by some other customer.") if dc_count.dc_total > 0
    end
  end
  #  validates_associated  :company, :customer_category, :memo_terms, :invoice_terms, :shipping
  
  #  validate do
  #    #    errors.add(:memo_term_id," does not exist") if not self.memo_terms
  #    #    errors.add(:inv_term_id," does not exist") if not self.invoice_terms
  #  end
  
  
  after_create do
    if is_blank_id?("#{self.billto_id}")
      self.update_attributes({:billto_id => self.id, :billto_code => self.code})
    end
    parent = Customer::Customer.find_by_id(self.billto_id)
    errors.add(''," Not a valid Parent# ") if  parent.id != parent.billto_id
  end

  def add_line_details(line_doc)
    id =  parse_xml(line_doc/'id') if (line_doc/'id').first
    line = asirankings(line_doc.name,id) || notes(line_doc.name,id) || shippings(line_doc.name,id)|| salespeople(line_doc.name,id) || relationships(line_doc.name,id) || item_pricings(line_doc.name,id) || contacts(line_doc.name,id) || production_days(line_doc.name,id)|| grouplines(line_doc.name,id) || harmonious_costs(line_doc.name,id) || customer_buying_groups(line_doc.name,id) || nil 
    line.apply_attributes(line_doc) if line
    line.fill_default_detail_values if (line_doc.name == 'customer_item_pricing')
    line
  end
  
  def grouplines(name,id)
    customer_group_lines.find_or_build(id) if name == 'customer_group_line'
  end
  
  def production_days(name,id)
    customer_item_production_days.find_or_build(id) if name == 'customer_item_production_day'
  end
  
  def harmonious_costs(name,id)
    customer_item_harmonious_costs.find_or_build(id) if name == 'customer_item_harmonious_cost'
  end
  
  def asirankings(name,id)
    customer_asirankings.find_or_build(id) if name == 'customer_asiranking'
  end
 
  def notes(name,id)
    customer_notes.find_or_build(id) if name == 'customer_daily_note'
  end
 
  def shippings(name,id)
    customer_shippings.find_or_build(id)  if name == 'shipping'
  end
 
  def salespeople(name,id)
    customer_salespeople.find_or_build(id)  if name == 'customer_salesperson'
  end
  
  def relationships(name,id)
    customer_relationships.find_or_build(id)  if name == 'customer_relationship'
  end
  
  def contacts(name,id)
    customer_contacts.find_or_build(id)  if name == 'customer_contact'
  end
  #  def wishlists(name,id)
  #    customer_wishlists.find_or_build(id)  if name == 'customer_wishlist'
  #  end

  def item_pricings(name,id)
    customer_item_pricings.find_or_build(id)  if name == 'customer_item_pricing'
  end

  def customer_buying_groups(name,id)
    customer_buying_group.find_or_build(id) if name == 'customer_buying_group' 
  end

  def apply_header_fields_to_lines()
    # self.customer_contacts.active.each{ |line| line.customer_code = self.code}
    self.customer_contacts.each{ |line| line.customer_code = self.code if line.trans_flag == 'A'}
  end

  def save_lines
    #    customer_asirankings.save_line 
    customer_asirankings.save_updated_line 
    #    customer_notes.save_line 
    #    customer_notes.save_updated_line # old table not in use now
    #customer_shippings.save_line 
    #    customer_salespeople.save_line
    customer_salespeople.save_updated_line
    #    customer_relationships.save_line
    customer_relationships.save_updated_line
    #    customer_wishlists.save_line
    #   customer_item_pricings.save_line
    customer_item_pricings.save_updated_line
    #    customer_contacts.save_line
    customer_contacts.save_updated_line
    #    customer_item_production_days.save_line
    customer_item_production_days.save_updated_line
    #    customer_group_lines.save_line
    customer_group_lines.save_updated_line
    #  customer_item_harmonious_costs.save_line
    customer_item_harmonious_costs.save_updated_line
    customer_buying_group.save_updated_line
  end
  
  def add_line_errors_to_header
    add_line_item_errors(customer_asirankings) if customer_asirankings
    add_line_item_errors(customer_notes) if customer_notes
    add_line_item_errors(customer_shippings) if customer_shippings
    add_line_item_errors(customer_salespeople) if customer_salespeople
    add_line_item_errors(customer_relationships) if customer_relationships
    #    add_line_item_errors(customer_wishlists) if customer_wishlists
    add_line_item_errors(customer_item_pricings)if customer_item_pricings
    add_line_item_errors(customer_contacts)if customer_contacts
    add_line_item_errors(customer_item_production_days) if customer_item_production_days
    add_line_item_errors(customer_group_lines) if customer_group_lines
    add_line_item_errors(customer_item_harmonious_costs) if customer_item_harmonious_costs
    add_line_item_errors(customer_buying_group) if customer_buying_group
  end


  def create_customer_transaction_activity(customer_activity_code)
    activity = self.customer_transaction_activities.build
    activity.company_id = self.company_id
    activity.customer_activity_code = customer_activity_code
    activity.updated_by =   self.updated_by || self.created_by
    activity.created_by =   self.updated_by
    activity.created_at = self.updated_at
    activity.updated_at = self.updated_at
    activity.update_flag = self.update_flag
    activity.trans_flag = self.trans_flag
    activity.activity_date = Time.now
    activity.sequence_no = 100 
    activity.user_id = Admin::User.current_user #self.updated_by || self.created_by
    return activity
  end

  after_save :find_or_create_prospect
  def find_or_create_prospect
    Crmb::CrmbProspectCrud.find_or_create_prospect_from_customer(self)
  end
 
end


