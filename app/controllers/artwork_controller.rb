class ArtworkController < ApplicationController

    def show_order_and_artwork_flow
        # doc = Hpricot::XML(request.raw_post)
        # order_id  = parse_xml(doc/:params/'id')
        #trans_no = request.params[:trans_no]
        # doc = Hash.from_xml(request.raw_post).to_json
        # binding.pry
        # order_id = doc["params"]["id"]
        trans_no = request.params[:trans_no]
        @orders = Artwork.show_order_and_artwork_flow(trans_no)
        # binding.pry
        # render :xml=>@orders[0].xmlcol
       # render_json_error(message: 'Ticket is invalid')
        render_json orders: @orders
    end

end