# /packages/intranet-portfolio-planner/tcl/intranet-portfolio-planner.tcl
#
# Copyright (C) 2010-2013 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    Portfolio Planner library.
    @author frank.bergmann@project-open.com
}



# ----------------------------------------------------------------------
# Portlets
# ---------------------------------------------------------------------

ad_proc -public im_portfolio_planner_component {
    {-program_id ""}
} {
    Returns a HTML widget with the portfolio planner
} {
    set params [list \
		    [list program_id $program_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-portfolio-planner/lib/portfolio-planner"]
    return [string trim $result]
}

