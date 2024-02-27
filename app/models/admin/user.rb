require 'digest/sha1'

class Admin::User < ActiveRecord::Base
  include Dbobject
  cattr_accessor :current_user
  # Virtual attribute for the unencrypted password
  attr_accessor :password,:url_with_port
  include UserStamp
  include Dbobject
  include General
  include ClassMethods
  # require 'has_finder'

  #has_many :user_permissions, :uniq => true , :class_name => "Admin::UserPermission",:extend=>ExtendAssosiation
  has_many :user_permissions ,  -> { uniq } , class_name: "Admin::UserPermission", :extend=>ExtendAssosiation
  has_many :user_companies, :class_name => "Admin::UserCompany"
  has_many :user_registered_machines, :class_name => "Admin::UserRegisteredMachine" ,:dependent => :destroy, :extend=>ExtendAssosiation
  has_many :moodules, :through=>:role_permissions, :class_name => "Admin::Moodule "
  has_many :roles, :through => :user_permissions, :class_name => "Admin::Role "
  has_many :notes, :class_name => "Setup::Note"
  has_many :attachments, :class_name => "Setup::Attachment"
  has_many :instance_transitions, :class_name => "Workflow::InstanceTransition"
  has_many :user_transaction_activities, :class_name =>'Admin::UserTransactionActivity' ,:extend=>ExtendAssosiation
  has_many :indigo_printer_users, :class_name =>'Admin::IndigoPrinterUser' ,:extend=>ExtendAssosiation
  has_many :user_members, :class_name =>'Admin::UserMember',:extend=>ExtendAssosiation
  #scope :activeusers, :conditions => { :trans_flag => 'A' }
  # scope :activedocuments, :where => { :trans_flag => 'A'}


  #   :my_assets, :class_name => 'Asset', :conditions => 'user_id = #{id}'

  #validates     :login, :email,:presence => true
  validates     :password,                   :if => :password_required?,:presence => true
  validates     :password_confirmation,      :if => :password_required?,:presence => true
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  #validates_length_of       :email,    :within => 3..100, :message => 'Length should be 3 to 100 characters'
  #validates_format_of       :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i ,:message=>'not Valid' #validation added to front end
  # validates_uniqueness_of   :login, :email, :case_sensitive => false,:on => :create
  validates_uniqueness_of   :login, :email, :case_sensitive => false,:on => :create,  conditions: -> { where(trans_flag: 'A') }
  #  validates_uniqueness_of   :user_cd, :case_sensitive => false   #9feb2017 validation commented
  validate :validate_user_cd 
  before_save :encrypt_password
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  #attr_accessible :login, :email, :password, :password_confirmation,:first_name,:last_name,:customer_id,:vendor_id,:login_flag_id,:category_id,
  #  :login_type, :type_id, :company_id, :id

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login_and_trans_flag(login,'A') # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  def self.authenticate_promostandard(login, password)
    u = Admin::User.find_by_sql("select * from users where login = '#{login}' and login_type in ('C','G','P') and trans_flag = 'A' ") 
    !u.blank? && u[0].authenticated?(password) ? u[0] : nil
  end
  
  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(:validate => false)
  end

  def session_autheticate?(user_id)
     self.id == user_id    
  end
  
  def create_user_transaction_activity(user_activity_code)
    activity = self.user_transaction_activities.build
    activity.company_id = self.company_id
    activity.user_activity_code = user_activity_code
    activity.updated_by =   self.updated_by || self.created_by
    activity.created_by =   self.updated_by
    activity.created_at = self.updated_at
    activity.updated_at = self.updated_at
    activity.update_flag = self.update_flag
    activity.trans_flag = self.trans_flag
    activity.activity_date = Time.now   
    activity.sequence_no = 100 
    activity.updated_by_user_id  = Admin::User.current_user #self.updated_by || self.created_by      
    return activity
  end

  protected
  # before filter
  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end

  def validate_user_cd
    unless self.user_cd.blank?
      count =  Admin::User.find_by_sql(["select count (*) as user_cd_total from users where trans_flag = 'A' and user_cd = '#{self.user_cd}' and id != '#{self.id}'"])[0]
      errors.add(' ', " Short Name Already taken by some other user.") if count.user_cd_total > 0
    end
  end

  def password_required?
    crypted_password.blank? || !password.blank?
  end

 def user_machines(name,id)
    user_registered_machines.find_or_build(id) if name == 'user_registered_machine'
  end

  def save_lines
    user_registered_machines.save_line
  end

  def add_line_errors_to_header
    add_line_item_errors(user_registered_machines) if user_registered_machines
  end

  def self.authenticate_schema_user_registered_machine(encrypted_key)
    access_code = Setup::Type.find(:first, :conditions=>['type_cd = ? and subtype_cd = ?','access_code','machine_level']) || Setup::Type.new
    is_accessible = true
    if access_code.value.to_s == 'Y'
      machine =  Admin::RegisteredMachine.find_by_sql ["select approve_flag from registered_machines
                                                where machine_encrypted_code = ?  
                                                and registered_machines.approve_flag = 'Y'
                                                and registered_machines.trans_flag = 'A' " ,encrypted_key.to_s]
      if machine[0]
        is_accessible = true
      else
        is_accessible = false
      end
    end
    return is_accessible
  end

end
