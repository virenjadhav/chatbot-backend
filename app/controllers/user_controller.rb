class UserController < ApplicationController

	def main_user_login
		# binding.pry
		# doc = JSON.parse(request.params)
		login = request.params[:login]
    	# password = doc["params"]["password"]
    	password = request.params[:password]
    	# binding.pry
    	# binding.pry
    	@user,@result,@message = User.authenticate(login, password)
    	# binding.pry
    	if @result == 'error'
    		render_json_error(message: @message)
    	else
    		render_json(user: @user)
    	end
    	# binding.pry
	end
end