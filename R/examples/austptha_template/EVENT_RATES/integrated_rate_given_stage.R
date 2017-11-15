#
# Code to integrate the stage-vs-rate curves for all source-zones
#

library(rptha)

all_tsunami_stage_exceedance_rates = Sys.glob('../SOURCE_ZONES/*/TSUNAMI_EVENTS/tsunami_*.nc')

fid = nc_open(all_tsunami_stage_exceedance_rates[1], readunlim=FALSE)
# The following variables are identical in all netcdf files
stage_seq = ncvar_get(fid, 'stage')
gauge_points = list()
gauge_points$lon = ncvar_get(fid, 'lon')
gauge_points$lat = ncvar_get(fid, 'lat')
gauge_points$elev = ncvar_get(fid, 'elev')
gauge_points$gaugeID = ncvar_get(fid, 'gaugeID')
# 

rate_mat_template = ncvar_get(fid, 'stochastic_slip_rate')*0
nc_close(fid)

stochastic_slip_rates = list(
    rates=rate_mat_template, 
    rates_upper_ci = rate_mat_template, 
    rates_lower_ci = rate_mat_template)
uniform_slip_rates = stochastic_slip_rates
variable_uniform_slip_rates = stochastic_slip_rates


for(i in 1:length(all_tsunami_stage_exceedance_rates)){
    
    fid = nc_open(all_tsunami_stage_exceedance_rates[i], readunlim=FALSE)

    stochastic_slip_rates$rates = stochastic_slip_rates$rates + ncvar_get(fid, 'stochastic_slip_rate')
    stochastic_slip_rates$rates_upper_ci = stochastic_slip_rates$rates_upper_ci + ncvar_get(fid, 'stochastic_slip_rate_upper_ci')
    stochastic_slip_rates$rates_lower_ci = stochastic_slip_rates$rates_lower_ci + ncvar_get(fid, 'stochastic_slip_rate_lower_ci')

    uniform_slip_rates$rates = uniform_slip_rates$rates + ncvar_get(fid, 'uniform_slip_rate')
    uniform_slip_rates$rates_upper_ci = uniform_slip_rates$rates_upper_ci + ncvar_get(fid, 'uniform_slip_rate_upper_ci')
    uniform_slip_rates$rates_lower_ci = uniform_slip_rates$rates_lower_ci + ncvar_get(fid, 'uniform_slip_rate_lower_ci')
    
    variable_uniform_slip_rates$rates = variable_uniform_slip_rates$rates + ncvar_get(fid, 'variable_uniform_slip_rate')
    variable_uniform_slip_rates$rates_upper_ci = variable_uniform_slip_rates$rates_upper_ci + ncvar_get(fid, 'variable_uniform_slip_rate_upper_ci')
    variable_uniform_slip_rates$rates_lower_ci = variable_uniform_slip_rates$rates_lower_ci + ncvar_get(fid, 'variable_uniform_slip_rate_lower_ci')

    nc_close(fid)
}


#stage_1m = which.min(abs(stage_seq - 1.0))
#stoch_1m = stoch_rate[stage_1m,]

#output_df = data.frame(lon=as.numeric(lon), lat=as.numeric(lat), elev_MSL=as.numeric(elev), rate1m=as.numeric(stoch_1m))
#
#output_spdf = SpatialPointsDataFrame(coords=output_df[,1:2], data=output_df[,3:4],
#    proj4string=CRS("+init=epsg:4326"), match.ID=FALSE)
#
#writeOGR(output_spdf, dsn='one_m_exceedance_rate', layer='one_m_exceedance_rate',
#    driver='ESRI Shapefile', overwrite=TRUE)



#'
#' Take care of saving outputs to netcdf file
#'
#'
create_integrated_rate_netcdf_file<-function(
    gauge_points, 
    stage_seq, 
    uniform_slip_rates, 
    stochastic_slip_rates,
    variable_uniform_slip_rates){

    # Dimension for rate curve
    dim_stage_seq = ncdim_def('stage', 'm', vals=stage_seq, unlim=FALSE,
        longname='stages corresponding to tsunami wave height exceedance rates')

    # Dimension for gauges
    dim_station = ncdim_def('station', '', vals=1:length(gauge_points$lon), 
        unlim=TRUE,
        longname='integer index corresponding to the gauge location')

    # Variables for gauge locations
    gauge_lon_v = ncvar_def(name='lon', units='degrees_east', 
        dim=list(dim_station), missval=NA, longname='station_longitude', 
        prec='float')
    gauge_lat_v = ncvar_def(name='lat', units='degrees_north', 
        dim=list(dim_station), missval=NA, longname='station_latitude', 
        prec='float')
    gauge_elev_v = ncvar_def(name='elev', units='m', dim=list(dim_station), 
        missval=NA, longname='station_ground_elevation_above_mean_sea_level', 
        prec='float')
    gauge_id_v = ncvar_def(name='gaugeID', units='', dim=list(dim_station), 
        missval=NA, longname='real_ID_for_each_station', prec='float')

    all_nc_var = list(gauge_lon_v, gauge_lat_v, gauge_elev_v, gauge_id_v)

    # Variables for rates, uniform slip
    uniform_rate_v = ncvar_def(
        name='uniform_slip_rate', units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate of peak stage for uniform slip events',
        missval=NA,
        prec='float')

    uniform_rate_upper_v = ncvar_def(
        name='uniform_slip_rate_upper_ci', units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (upper credible interval) of peak stage for uniform slip events',
        missval=NA,
        prec='float')

    uniform_rate_lower_v = ncvar_def(
        name='uniform_slip_rate_lower_ci', units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (lower credible interval) of peak stage for uniform slip events',
        missval=NA, prec='float')

    all_nc_var = c(all_nc_var,
        list(uniform_rate_v, uniform_rate_upper_v, uniform_rate_lower_v))

    #
    # Variables for rates, stochastic slip
    #
    stochastic_rate_v = ncvar_def(
        name='stochastic_slip_rate', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate of peak stage for stochastic slip events',
        missval=NA, prec='float')

    stochastic_rate_upper_v = ncvar_def(
        name='stochastic_slip_rate_upper_ci', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (upper credible interval) of peak stage for stochastic slip events',
        missval=NA, prec='float')

    stochastic_rate_lower_v = ncvar_def(
        name='stochastic_slip_rate_lower_ci', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (lower credible interval) of peak stage for stochastic slip events',
        missval=NA, prec='float')

    all_nc_var = c(all_nc_var, 
        list(stochastic_rate_v, stochastic_rate_upper_v, 
            stochastic_rate_lower_v))

    #
    # Variables for rates, variable_uniform slip
    #
    variable_uniform_rate_v = ncvar_def(
        name='variable_uniform_slip_rate', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate of peak stage for variable_uniform slip events',
        missval=NA, prec='float')

    variable_uniform_rate_upper_v = ncvar_def(
        name='variable_uniform_slip_rate_upper_ci', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (upper credible interval) of peak stage for variable_uniform slip events',
        missval=NA, prec='float')

    variable_uniform_rate_lower_v = ncvar_def(
        name='variable_uniform_slip_rate_lower_ci', 
        units='events per year',
        dim=list(dim_stage_seq, dim_station), 
        longname = 'exceedance rate (lower credible interval) of peak stage for variable_uniform slip events',
        missval=NA, prec='float')

    all_nc_var = c(all_nc_var, 
        list(variable_uniform_rate_v, variable_uniform_rate_upper_v, 
            variable_uniform_rate_lower_v))

    # Make name for output file
    sourcename_dot_nc = 'sum_over_all_source_zones.nc'
    output_file_name = paste0('tsunami_stage_exceedance_rates_', sourcename_dot_nc)

    # Create output file
    output_fid = nc_create(output_file_name, vars=all_nc_var)

    # Put attributes on file
    ncatt_put(output_fid, varid=0, attname='parent_script_name',
        attval=parent_script_name(), prec='text')

    # Put gauge info on file
    ncvar_put(output_fid, gauge_lon_v, gauge_points$lon)
    ncvar_put(output_fid, gauge_lat_v, gauge_points$lat)
    ncvar_put(output_fid, gauge_elev_v, gauge_points$elev)
    ncvar_put(output_fid, gauge_id_v, gauge_points$gaugeID)

    # Put uniform slip stage exceedance rates on file
    ncvar_put(output_fid, uniform_rate_v, uniform_slip_rates$rates)
    ncvar_put(output_fid, uniform_rate_upper_v, 
        uniform_slip_rates$rates_upper_ci)
    ncvar_put(output_fid, uniform_rate_lower_v, 
        uniform_slip_rates$rates_lower_ci)

    # Put stochastic slip stage exceedance rates on file
    ncvar_put(output_fid, stochastic_rate_v, 
        stochastic_slip_rates$rates)
    ncvar_put(output_fid, stochastic_rate_upper_v, 
        stochastic_slip_rates$rates_upper_ci)
    ncvar_put(output_fid, stochastic_rate_lower_v, 
        stochastic_slip_rates$rates_lower_ci)

    # Put variable_uniform slip stage exceedance rates on file
    ncvar_put(output_fid, variable_uniform_rate_v, 
        variable_uniform_slip_rates$rates)
    ncvar_put(output_fid, variable_uniform_rate_upper_v, 
        variable_uniform_slip_rates$rates_upper_ci)
    ncvar_put(output_fid, variable_uniform_rate_lower_v, 
        variable_uniform_slip_rates$rates_lower_ci)

    nc_close(output_fid)

    return(invisible(output_file_name))
}

#
# Make the file
#
create_integrated_rate_netcdf_file(
    gauge_points, 
    stage_seq, 
    uniform_slip_rates, 
    stochastic_slip_rates,
    variable_uniform_slip_rates)