
module spherical_mod
    !
    ! Useful routines for computation on sphere
    !
    use global_mod, only: dp, ip, radius_earth
    use iso_c_binding, only: C_DOUBLE
    implicit none

    real(dp), parameter, private:: PI = atan(1.0_dp)*4.0_dp
    real(dp), parameter :: DEG2RAD = PI/180.0_dp
    ! Radians/second of earth rotation
    real(dp), parameter :: EARTH_ANGULAR_FREQ = 2.0_dp * PI / (3600.0_dp * 24.0_dp)

    CONTAINS

    ! Compute the area on a sphere of a 'rectangle' bounded by lines of
    ! constant latitude and longitude, defined by lon1, lon1+dlon, lat1, lat1+dlat.
    ! Here lon1, lat1 must be the lower-left corner
    !
    ! The input parameters are in degrees, with latitude ranging from -90 to 90
    !
    ! Solution is explained here
    ! http://mathforum.org/library/drmath/view/63767.html
    !
    ! Note similarity with area = R^2 cos(lat) * dlat * dlon.
    ! The equation here is similar if we note [sin(lat+dlat)-sin(lat)]/dlat = cos(lat)
    ! as dlat --> 0
    ! If flat=.true. then we use the 'cos' formula, but if flat=.FALSE. (default) we do not.
    elemental function area_lonlat_rectangle(lon1, lat1, dlon, dlat, flat) result (area_sp)
        real(dp), intent(in):: lon1, lat1, dlon, dlat
        logical, optional, intent(in):: flat
        real(dp) :: area_sp
        logical:: flat_flag
        real(C_DOUBLE):: sin1, sin2

        if(present(flat)) then
            flat_flag = flat
        else
            flat_flag = .FALSE.
        end if

        if(flat_flag) then
            area_sp = radius_earth * radius_earth * &
                cos((lat1 + 0.5_dp*dlat)*DEG2RAD) * abs(dlat) * DEG2RAD *&
                mod(abs(dlon), 360.0_dp)*DEG2RAD
        else
            ! Here with single precision, we make an effort to avoid
            ! cancellation in the diff(sin) term. Otherwise in the unit-tests,
            ! we would need different error tol's for single and double dp
            sin1 = sin(real(lat1, C_DOUBLE)*real(DEG2RAD, C_DOUBLE))
            sin2 = sin((real(lat1, C_DOUBLE) + real(dlat, C_DOUBLE)) * real(DEG2RAD, C_DOUBLE))
            area_sp = radius_earth * radius_earth * &
                abs( sin1 - sin2 ) * &
                mod(abs(dlon), 360.0_dp)*DEG2RAD
        end if

    end function

    subroutine test_spherical_mod()
        real(dp):: lon1, lon2, lat1, lat2, area
        real(dp):: ans 
        ! the test cases assume this radius
        real(dp), parameter:: test_radius = 6378137.0_dp
        real(dp), parameter:: radius_adjustment_factor = (test_radius/radius_earth)**2 

        !! Test 1
        ans = 12391399902.0_dp
        lon1 = 0.0_dp
        lon2 = 1.0_dp
        lat1 = 0.0_dp
        lat2 = 1.0_dp

        area = area_lonlat_rectangle(lon1, lat1, 1.0_dp, 1.0_dp)

        if(abs(area*radius_adjustment_factor - ans) < 1.0e-06_dp * ans ) then
            print*, 'PASS'
        else
            print*, 'FAIL'
        end if

        ! Test 1.5 -- 'flat' case
        ans = radius_earth * radius_earth * cos(0.5_dp * DEG2RAD) * 1.0_dp * DEG2RAD * 1.0_dp * DEG2RAD
        area = area_lonlat_rectangle(lon1, lat1, 1.0_dp, 1.0_dp, .TRUE.)
        if(abs(area - ans) < 1.0e-06_dp * ans) then
            print*, 'PASS'
        else
            print*, 'FAIL'
        end if
        
    
        !! Test 2
        ans = 3379082.32316_dp
        lon1 = 108.0_dp 
        lon2 = 108.0_dp + 1.0_dp/60.0_dp
        lat1 = -11.0_dp
        lat2 = -11.0_dp + 1.0_dp/60.0_dp

        area = area_lonlat_rectangle(lon1, lat1, 1.0_dp/60.0_dp, 1.0_dp/60.0_dp)

        if(abs(area*radius_adjustment_factor - ans) < 1.0e-06_dp * ans) then
            print*, 'PASS'
        else
            print*, 'FAIL', area * radius_adjustment_factor, ans
        end if

        !! Test 3
        ans = 1689517.29722_dp
        lon1 = 108.0_dp 
        lon2 = 108.0_dp + 1.0_dp/60.0_dp
        lat1 = -11.0_dp
        lat2 = -11.0_dp + 1.0_dp/120.0_dp

        area = area_lonlat_rectangle(lon1, lat1, 1.0_dp/60.0_dp, 1.0_dp/120.0_dp)

        if(abs(area*radius_adjustment_factor - ans) < 1.0e-06_dp * ans) then
            print*, 'PASS'
        else
            print*, 'FAIL', area * radius_adjustment_factor, ans
        end if

    end subroutine

end module
