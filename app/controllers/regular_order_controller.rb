class RegularOrderController < ApplicationController

  # after_filter :set_content_type, :only => [:show_order]

  # def set_content_type
  #   content_type = 'application/xml'
  #   response.headers["Content-Type"] = "#{content_type}"
  # end
  
  ## Standard/Regular AND ReOrder Order Services
  # skip_before_action :verify_authenticity_token
  def create_cancel_orders
      # schema_name = get_schema_name(request.host)
      # render :xml => '<errors><error>Company Not Exists!!</error></errors>' if schema_name.blank?
      # doc = Hpricot::XML(request.raw_post)
      trans_no = request.params[:trans_no]
      order_cancellation_reason = request.params[:order_cancellation_reason]
      @order, result, message = Sales::SalesOrderLib.create_cancel_order(trans_no, order_cancellation_reason)
      if result == 'error'
        render_json_error(message: message)
      else
        render_json(enquiry: @order)
      end
    end

  def order_on_hold
    # doc = Hpricot::XML(request.raw_post)
    user_id = request.params[:user_id]
    hold_order_reason = request.params[:hold_order_reason]
    trans_no = request.params[:trans_no]
    @order, result, message = Sales::SalesOrderLib.order_on_hold(trans_no, user_id, hold_order_reason)
    if result == 'error'
        render_json_error(message: message)
      else
        render_json(enquiry: @order)
      end
  end

  
  def delete_sales_order 
    doc = Hpricot::XML(request.raw_post)
    order_id  = parse_xml(doc/:params/'id')
    order = Sales::SalesOrderUtilites.delete_sales_order(order_id)
    if order.errors.empty?
      render :xml => {:result =>"Sub order deleted successfully"}.to_xml(:root => 'results')
    else
      respond_to_errors(order.errors)
    end
  end

  def update_billing_address
    doc = Hpricot::XML(request.raw_post) 
    doc = doc.to_s.gsub("&amp;","&") 
    doc = Hpricot::XML(doc)  
    message,message_status = Sales::SalesRegularOrderCrud.update_billing_address(doc)
    
    if message_status=='Successful'
     render :xml => {:result =>"Billing Address Updated successfully"}.to_xml(:root => 'results')
    else
      render :xml => "<errors><error>#{message}</error></errors>"
    end
  end
end
