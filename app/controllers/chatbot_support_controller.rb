class ChatbotSupportController < ApplicationController

	def track_support_enquiries
		trans_no = request.params[:trans_no]
		@enquiries, result = ChatbotEnquiries.track_support_enquiries(trans_no)
		# binding.pry
		if result == 'error'
    		render_json_error(message: 'Ticket is invalid')
    	else
    		render_json(enquiry: @enquiries)
    	end
	end

end