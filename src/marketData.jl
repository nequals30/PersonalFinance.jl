using YFinance, Dates, DataFrames

export populate_yfinance_prices


function populate_yfinance_prices(v::Vault,assets::AbstractVector{<:AbstractString})
	# assets should be optional. if unspecified, it should figure out what assets are YFINANCE in terms of pricing methodology
	# optional start date and end date, otherwise it will figure it out from when dates first appear
	
	# automatically figure out minimum date of first transaction accross all assets specified	
	asset_ids = assetName2assetId(v,assets)
	asset_ids_str = join(asset_ids, ",")
	startDt = Date(first(DBInterface.execute(v.db,"""
			 select min(trans_date) from transactions where asset_id in ($(asset_ids_str))
		   ;"""))[1])

	endDt = today()

	raw_data = get_prices.(assets,interval="1d", startdt=startDt, enddt=endDt)
	x = vcat([DataFrame(i) for i in raw_data]...)

	return x
end
