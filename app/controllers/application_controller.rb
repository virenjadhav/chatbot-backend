class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
	def is_json_request?
    return request.headers['Content-Type'].present? && request.headers['Content-Type'].downcase == 'application/json'
  end
  def render_json(data)
    # binding.pry
    render json: { result: "success", message: "", data: data }, status: :ok
  end
  def render_json_error(massage)
    # binding.pry
    render json: { result: 'error', message: massage[:message], data: nil }, status: :ok
  end
end
