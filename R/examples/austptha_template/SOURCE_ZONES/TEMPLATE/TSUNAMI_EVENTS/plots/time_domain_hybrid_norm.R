
#
# Function to measure the 'similarity' between 2 time-series [stage-gauges]
#
# gauge1: data1_t, data1_s ; vectors of time/stage values -- should correspond to DATA.
# gauge2: data2_t, data2_s ; vectors of time/stage values [note times do not
#   need to correspond exactly to data1_t, since interpolation is used to create
#   a common time scale]
#
gauge_similarity_time_domain<-function(
    data1_t, 
    data1_s, 
    data2_t, 
    data2_s, 
    interp_dt = NULL,
    allowed_lag_minutes=c(-15, 0), 
    time_range=range(data1_t), 
    detailed=FALSE){
    
    if(is.null(interp_dt)){
        interp_dt = min(c(diff(data1_t), diff(data2_t)))
    }

    # Interpolate the data
    interp1_t = approx(data1_t, data1_s, xout = seq(time_range[1], 
        time_range[2], by = interp_dt), rule=2)

    # Find min/max of data, and associated times
    newt = time_range
    mint = min(newt)
    maxt = max(newt)
    
   
    # Extract the model and data between the min/max times 
    data1_interp = list()
    data1_interp$x = interp1_t$x[which(interp1_t$x >= mint & interp1_t$x <= maxt)]
    data1_interp$y = interp1_t$y[which(interp1_t$x >= mint & interp1_t$x <= maxt)]
   
    ## Compute statistic from Lorito et al., 2008, eqn 2 
    #   = 1 - 2*(a.b)/(a.a + b.b)
    ## Note this is mathematically identical to (a-b).(a-b) / (a.a + b.b), i.e. normalised least squares
    ## We can add weights to emphasise the points with significant waves 
    f<-function(lag, weighted=TRUE){ 
        data2_interp = approx(data2_t - lag, data2_s, xout = data1_interp$x, rule=2)

        if(weighted){
            # Weight large-abs-value points more. Minimum point weight is not
            # less than 1/3 maximum point weight.
            w = pmax(abs(data1_interp$y),  max(abs(data1_interp$y))/3)
        }else{
            # Weight all points equally
            w = 1
        }

        Em = 1 - 2*sum(w*w*data1_interp$y * data2_interp$y)/
            ( sum(w*w*data1_interp$y^2) + sum(w*w*data2_interp$y^2))
        return(Em)
    }

    # Test lags between min/max, with spacing of about 10s
    # Implement our own brute force minimization, since the R function "optimize" appears like
    # it might not hit the minimum reliably for this problem.
    sec_in_min = 60
    lag_vals = seq(sec_in_min * allowed_lag_minutes[1], sec_in_min*allowed_lag_minutes[2], 
        length=max(1, ceiling(diff(allowed_lag_minutes)*sec_in_min/10)) )
    lag_f = lag_vals*0
    for(i in 1:length(lag_vals)){
        lag_f[i] = f(lag_vals[i])
    }

    #best_lag = optimize(f, interval=sec_in_min*allowed_lag_minutes)
    # Make the output 'look like' output from a call to optimize
    best_lag = list(objective=min(lag_f), minimum = lag_vals[which.min(lag_f)])

    if(!detailed){
        return(best_lag$objective)
    }else{
        return(best_lag)
    }

}
