class Setup::Company < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include General
  #  require 'has_finder' 
  has_many :sequences, :class_name => 'Setup::Sequence' , :extend=>ExtendAssosiation
  has_many :company_locations, :class_name => 'Setup::CompanyLocation' , :extend=>ExtendAssosiation
  has_one :default_company_store, :class_name => 'Setup::CompanyStore', :foreign_key=> 'default_store_id'
 # has_many :user_companies, :class_name => 'Admin::UserCompany' , :extend=>ExtendAssosiation
  #  scope :activecompany, :conditions => { :trans_flag => 'A' }
  
  validates_uniqueness_of   :company_cd
  
  validate :store_count
  
  def add_line_details(user_company_doc)
    id =  parse_xml(user_company_doc/'id') if (user_company_doc/'id').first
    #line = user_company_lines(user_company_doc.name,id) || 
    line =  book_lines(user_company_doc.name,id) || store_locations(user_company_doc.name,id) || nil
    company_id =  line.company_id if line
    line.apply_attributes(user_company_doc) if line
    line.company_id = company_id if !line.new_record?
    line.company_code = self.company_cd  if (line.new_record? and user_company_doc.name == 'company_location')
    line.fill_default_detail_values
  end
  
  # def user_company_lines(name,id)
  #   user_companies.find_or_build(id) if name == 'user_companie'
  # end

  def book_lines(name,id)
    sequences.find_or_build(id) if name == 'sequence' 
  end
  
  def store_locations(name,id)
    company_locations.find_or_build(id) if name == 'company_location'
  end

  # def save_user_companies
  #   user_companies.save_line
  # end

  def save_locations
    company_locations.save_line
  end

  def save_sequences
    sequences.save_line
  end

  def add_line_errors_to_header
    #add_line_item_errors(user_companies)
    add_line_item_errors(sequences)
    add_line_item_errors(company_locations)
  end

  def fill_default_header_values
 
  end
  
  def store_count
    if self.new_record?
      valid_store_count = Setup::Type.find(:first, :conditions=>['type_cd = ? and subtype_cd = ?','application_license','store'])
      if (valid_store_count and valid_store_count.value and valid_store_count.value.to_s != '' and valid_store_count.value != 0)
        store_count = Setup::Company.find_by_sql ["select count(*) as store_no from companies where trans_flag = 'A' and company_type <>'C' "]
        if store_count[0].store_no >= valid_store_count.value.to_i
          errors.add_to_base("Store number exceeds #{valid_store_count.value}")
        end
      end
    end
  end

end
