#ifdef TIMER
#   define TIMER_START(tname) call domain%timer%timer_start(tname)
#   define TIMER_STOP(tname)  call domain%timer%timer_end(tname)
#else
#   define TIMER_START(tname)
#   define TIMER_STOP(tname)
#endif

MODULE local_routines 
    USE global_mod, only: dp, ip, charlen, wall_elevation
    USE domain_mod, only: domain_type, STG, UH, VH, ELV
    USE read_raster_mod, only: gdal_raster_dataset_type
    USE which_mod, only: which
    USE file_io_mod, only: read_csv_into_array
    IMPLICIT NONE

    CONTAINS 

    SUBROUTINE set_initial_conditions_java(domain, input_elevation_raster, &
        input_stage_raster, hazard_points_file, skip_header,&
        adaptive_computational_extents, negative_elevation_raster)

        CLASS(domain_type), TARGET, INTENT(INOUT):: domain
        CHARACTER(len=charlen), INTENT(IN):: input_elevation_raster, &
            input_stage_raster, hazard_points_file
        INTEGER(ip), INTENT(IN):: skip_header
        LOGICAL, INTENT(IN):: adaptive_computational_extents, negative_elevation_raster

        INTEGER(ip):: i, j
        REAL(dp), ALLOCATABLE:: x(:), y(:), xy_coords(:,:)
        INTEGER(ip):: stage_raster_dim(2), xl, xU, yl, yU
        REAL(dp) :: stage_raster_ll(2), stage_raster_ur(2)
        TYPE(gdal_raster_dataset_type):: elevation_data, stage_data

        ! Make space for x/y coordinates, at which we will look-up the rasters
        ALLOCATE(x(domain%nx(1)), y(domain%nx(1)))

        x = domain%x

        print*, "Setting elevation ..."

        CALL elevation_data%initialise(input_elevation_raster)

        print*, '    bounding box of input elevation: ' 
        print*, '    ', elevation_data%lowerleft
        print*, '    ', elevation_data%upperright

        ! Treat periodic case, where there will be 2 points on either side
        ! which exceed the input raster extent
        if(x(domain%nx(1)) - x(1) > 360.0_dp) then
            x(1:2) = x(1:2) + 360.0_dp
            x((domain%nx(1) - 1):domain%nx(1)) = x((domain%nx(1) - 1):domain%nx(1)) - 360.0_dp
        end if

        DO j = 1, domain%nx(2)
            y = domain%y(j)
            CALL elevation_data%get_xy(x, y, domain%U(:,j,ELV), domain%nx(1), &
                bilinear=1_ip)
            if(negative_elevation_raster) domain%U(:,j,ELV) = -domain%U(:,j,ELV)
        END DO
        CALL elevation_data%finalise()
    

        print*, "Setting stage ..."

        ! Set stage -- zero outside of initial condition file range
        domain%U(:,:,[STG,UH,VH]) = 0.0_dp
       
        CALL stage_data%initialise(input_stage_raster)

        ! Get the x indices which are inside the stage raster 
        ! We permit this to only cover a small part of the domain
        xl = COUNT(domain%x < stage_data%lowerleft(1)) + 1
        xU = COUNT(domain%x < stage_data%upperright(1))
        yl = COUNT(domain%y < stage_data%lowerleft(2)) + 1
        yU = COUNT(domain%y < stage_data%upperright(2))

        print*, '    bounding box of input stage: ' 
        print*, '    ', stage_data%lowerleft
        print*, '    ', stage_data%upperright
        print*, '    xl: ', xl, ' xU: ', xU
        print*, '    yl: ', yl, ' yU: ', yU

        if(xl > 0 .AND. xU > 0) then
            DO j = 1, domain%nx(2)
                if((domain%y(j) > stage_data%lowerleft(2)) .AND. &
                    (domain%y(j) < stage_data%upperright(2))) then
                    y(xl:xU) = domain%y(j)
                    CALL stage_data%get_xy(x(xl:xU), y(xl:xU), &
                        domain%U(xl:xU, j, STG), (xU-xl+1))
                end if
            END DO
        end if
        CALL stage_data%finalise() 

        print*, '    max stage: ', maxval(domain%U(:,:,STG))
        print*, '    min stage: ', minval(domain%U(:,:,STG))

        ! By updating the boundary, we prevent changes to the elevation that can occur
        ! e.g. if the elevation could be updated at edges by the boundary, 
        call domain%update_boundary()

        ! Ensure stage >= elevation
        domain%U(:,:,STG) = max(domain%U(:,:,STG), domain%U(:,:,ELV)+1.0e-06)



        ! Setup gauges
        if(hazard_points_file /= '') then
            print*, ''
            print*, 'Reading hazard points'
            call read_csv_into_array(xy_coords, hazard_points_file, skip_header)
            if( (any(xy_coords(1,:) < domain%lower_left(1))).OR. &
                (any(xy_coords(1,:) > domain%lower_left(1) + domain%lw(1))).OR. &
                (any(xy_coords(2,:) > domain%lower_left(2) + domain%lw(2))).OR. &
                (any(xy_coords(2,:) < domain%lower_left(2))) ) then
                print*, '    # WARNING: Some hazard points outside domain extents are being clipped'
                print*, '    #          (Could include points on the domain edge, due to round-off error)'
                print*, '    # The original hazard point range:'
                print*, '    #     lon: ', minval(xy_coords(1,:)), maxval(xy_coords(1,:))
                print*, '    #     lat: ', minval(xy_coords(2,:)), maxval(xy_coords(2,:))
                print*, '    # will be truncated to the range of the cell midpoints'
                xy_coords(1,:) = min(xy_coords(1,:), maxval(domain%x))
                xy_coords(1,:) = max(xy_coords(1,:), minval(domain%x))
                xy_coords(2,:) = min(xy_coords(2,:), maxval(domain%y))
                xy_coords(2,:) = max(xy_coords(2,:), minval(domain%y))
            end if
            print*, '    Setting up gauges'
            call domain%setup_point_gauges(xy_coords, time_series_var=[STG], static_var=[ELV])
            print*, '    The number of points is', domain%point_gauges%n_gauges
            print*, '    The first point is (lon,lat): ', xy_coords(1,1), xy_coords(2,1)
            print*, '    The last  point is (lon,lat): ', xy_coords(1:2, domain%point_gauges%n_gauges)
            print*, ''
            DEALLOCATE(xy_coords)
        else
            print*, ''
            print*, 'No hazard points'
            print*, ''
        end if
       
        if(adaptive_computational_extents) then
            ! Make up some xL/xU limits to do preliminary checks on allowing that
            ! to evolve
            domain%xL = xl
            domain%xU = xU
            domain%yL = yL
            domain%yU = yU
        end if

        DEALLOCATE(x,y)
        print*, 'Initial conditions set'
        print*, ''

        
    END SUBROUTINE

END MODULE 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

PROGRAM java

    USE global_mod, only: ip, dp, minimum_allowed_depth
    USE domain_mod, only: domain_type
    USE boundary_mod, only: flather_boundary, periodic_EW_reflective_NS
#ifdef COARRAY
    USE coarray_point2point_comms_mod, only: allocate_p2p_comms
#endif
    USE local_routines
    IMPLICIT NONE

    INTEGER(ip) :: i, j, ti, ni, nx_ca, ny_ca
    REAL(dp) :: last_write_time
    TYPE(domain_type) :: domain
    CHARACTER(charlen) :: timestepping_method, input_parameter_file
    REAL(dp) :: approximate_writeout_frequency, final_time 

    REAL(dp) :: global_ur(2), global_ll(2), global_lw(2), cfl, dx(2), local_lw(2), local_ll(2)
    INTEGER(ip) :: global_nx(2), local_nx(2)
    INTEGER(ip) :: skip_header_hazard_points_file
    CHARACTER(len=charlen) :: input_elevation_raster, input_stage_raster, &
        hazard_points_file, output_basedir, logfile_name
    LOGICAL :: record_max_U, output_grid_timeseries, adaptive_computational_extents, &
        negative_elevation_raster

    REAL(dp) :: timestep
    
    ! Input data
    namelist /MODELCONFIG/ &
        input_elevation_raster, input_stage_raster, global_ll, &
        global_ur, global_nx, approximate_writeout_frequency, output_basedir, &
        final_time, timestepping_method,&
        cfl, hazard_points_file, skip_header_hazard_points_file, record_max_U,&
        output_grid_timeseries, adaptive_computational_extents, negative_elevation_raster, &
        nx_ca, ny_ca
#ifdef COARRAY
    sync all
#endif
    TIMER_START('SETUP')

#ifdef COARRAY
    ni = num_images()
    ti = this_image()
#else
    ti = 1
    ni = 1
#endif

    ! Read input namelist 
    call get_command_argument(1, input_parameter_file)
    open(newunit=j, file=input_parameter_file, action='read')
    read(j, nml=MODELCONFIG)
    close(j)

    domain%myid = 1000 + ti

    print*, ''
    print*, '#### INPUT FROM MODELCONFIG ####'
    print*, ''
    print*, 'input_elevation_raster: ', TRIM(input_elevation_raster)
    print*, 'input_stage_raster: ', TRIM(input_stage_raster)
    print*, 'global_ll: ', global_ll
    print*, 'global_ur: ', global_ur
    print*, 'global_nx: ', global_nx
    print*, 'approximate_writeout_frequency: ', approximate_writeout_frequency
    print*, 'output_basedir: ', TRIM(output_basedir)
    print*, 'final_time: ', final_time
    print*, 'timestepping_method: ', TRIM(timestepping_method)
    print*, 'cfl: ', cfl
    print*, 'hazard_points_file: ', TRIM(hazard_points_file)
    print*, 'skip_header_hazard_points_file: ', skip_header_hazard_points_file
    print*, 'record_max_U: ', record_max_U
    print*, 'output_grid_timeseries: ', output_grid_timeseries
    print*, 'adaptive_computational_extents: ', adaptive_computational_extents
    print*, 'negative_elevation_raster: ', negative_elevation_raster
    print*, ''
    print*, '#### END INPUT ####'

    print*, ''
    print*, 'Other key variables: '
    print*, 'dp: ', dp
    print*, 'ip: ', ip
    print*, 'charlen: ', charlen

    global_lw = global_ur - global_ll
    dx = global_lw/(1.0_dp*global_nx)

    ! Use either ew-periodic or flather boundaries
    if(abs(global_lw(1) - 360.0_dp) < (0.1_dp*dx(1))) then
        ! Global model in EW direction.
        print*, ' Periodic case not yet supported with coarrays'
        error stop
        ! Case with periodic EW boundaries
        print*, ''
        print*, 'Assuming global model with periodic boundaries: Appending cells to domain'
        print*, ''
        domain%boundary_subroutine => periodic_EW_reflective_NS 

        global_nx = global_nx + [4,0]
        global_ur = global_ur + [2*dx(1), 0.0_dp]
        global_ll = global_ll - [2*dx(1), 0.0_dp]
        global_lw = global_ur - global_ll
    else
        domain%boundary_subroutine => flather_boundary
    end if

    domain%timestepping_method = timestepping_method
    domain%cfl = cfl
    domain%record_max_U = record_max_U
    domain%output_basedir = output_basedir

    
#ifndef COARRAY    
    CALL domain%allocate_quantities(global_lw, global_nx, global_ll)
#else
    print*, 'Allocating image ', ti
    ! Allocate domain with coarrays
    CALL domain%allocate_quantities(global_lw, global_nx, global_ll, co_size_xy = [nx_ca, ny_ca])
    sync all
    call allocate_p2p_comms
#endif
        CALL domain%log_outputs()
        write(domain%logfile_unit, MODELCONFIG)

        ! Call local routine to set initial conditions
        CALL set_initial_conditions_java(domain, input_elevation_raster,&
            input_stage_raster, hazard_points_file, skip_header_hazard_points_file,&
            adaptive_computational_extents, negative_elevation_raster)


#ifdef COARRAY
    ! Also print information about whether boundary conditions are applied
        write(domain%logfile_unit, *) 'ti: ', ti, 'boundary_exterior: ', domain%boundary_exterior
#endif

    timestep = domain%linear_timestep_max()
    if(domain%timestepping_method /= 'linear') then
        ! The Finite volume methods have 1/2 as long a timestep for the same cfl
        timestep = 0.5_dp * timestep
    end if

#ifdef COARRAY
    call co_min(timestep)
    write(domain%logfile_unit, *) 'reduced ts: ', timestep
#else
    write(domain%logfile_unit, *) 'ts: ', timestep
#endif

    ! Trick to get the code to write out just after the first timestep
    last_write_time = -approximate_writeout_frequency

#ifdef COARRAY
    sync all
#endif
    TIMER_STOP('SETUP')


    ! Evolve the code
    DO WHILE (.TRUE.)

        IF(domain%time - last_write_time >= approximate_writeout_frequency) THEN

            last_write_time = last_write_time + approximate_writeout_frequency

            CALL domain%print()
            CALL domain%write_to_output_files(time_only = (output_grid_timeseries .EQV. .FALSE.))
            CALL domain%write_gauge_time_series()

        END IF

        IF (domain%time > final_time) THEN
            EXIT 
        END IF

        !! Example with fixed timestep
        CALL domain%evolve_one_step(timestep=timestep)

        ! Evolve the active domain?
        domain%xL = max(domain%xL - 1, 1)
        domain%xU = min(domain%xU + 1, domain%nx(1))
        domain%yL = max(domain%yL - 1, 1)
        domain%yU = min(domain%yU + 1, domain%nx(2))

        ! Treatment of spherical models with periodic EW conditions
        ! The BC region is within 4 cells of the boundaries (considering
        ! cells that copy-out, as well as cells that copy-in)
        if((domain%xl <= 4).OR.(domain%xU >= domain%nx(1) - 3)) then
            domain%xl = 1_ip
            domain%xU = domain%nx(1)
        end if

    END DO

    print*, ''
    CALL domain%write_max_quantities()

    ! Print timing info
    CALL domain%timer%print(output_file_unit = domain%logfile_unit)

    CALL domain%finalise()

END PROGRAM
