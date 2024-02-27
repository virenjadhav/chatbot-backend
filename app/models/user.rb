require 'digest/sha1'
class User < ActiveRecord::Base

	cattr_accessor :current_user  
#  
  # Virtual attribute for the unencrypted password
  attr_accessor :password
#  belongs_to :main_company
  
  #   :my_assets, :class_name => 'Asset', :conditions => 'user_id = #{id}'
  
  validates     :login, :email,:presence => true
  validates     :password, :presence => true,                  :if => :password_required?
  validates     :password_confirmation,:presence => true,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  #validates_length_of       :email,    :within => 3..100, :message => 'Length should be 3 to 100 characters'
  validates_format_of       :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i ,:message=>'not Valid'
  validates_uniqueness_of   :login, :email, :case_sensitive => false ,:message => 'Email id has aleady been taken.. '

	before_save :encrypt_password
	def self.authenticate(login, password)
    	u = find_by_login(login)#,:conditions => ["trans_flag = 'A'"]) # need to get the salt
    	# binding.pry
    	return nil,"error",  "usename is not valid" if u.blank?
    	if u && u.authenticated?(password)
    		return u, "success", "Login Successfully."
    	else
    		return nil, "error", "Password does not match with Username."
    	end
    	# u && u.authenticated?(password) ? u: nil
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
#    puts encrypt(password)
  end

  def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end
end