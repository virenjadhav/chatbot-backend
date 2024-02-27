class ProspectEnquiry < ApplicationRecord



  def self.save_prospect_data(name,company_name,phone_no,email,message)
    pros_object = ProspectEnquiry.new
    pros_object.name = name
    pros_object.cname = company_name
    pros_object.pnumber = phone_no
    pros_object.email = email
    pros_object.message = message
    pros_object.save!
  end

  
end