class ChatbotOptionController < ApplicationController



  def get_chatbot_options
    doc = request.raw_post
    option_type = request.params["option_type"]
    @options = ChatbotOption.get_chatbot_options(option_type)
    render json: @options
  end

  def add_prospect_enquiry
    name = request.params["name"]
    company_name = request.params["company_name"]
    phone_no = request.params["phone_no"]
    email = request.params["email"]
    message = request.params["message"]
    @prosp = ProspectEnquiry.save_prospect_data(name,company_name,phone_no,email,message)
    render json: {result: 'success',message: 'We are thrilled to have you with us. Our team will contact with you soon.'}
  end



end



