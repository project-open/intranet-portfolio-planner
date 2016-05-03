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
    -report_start_date:required
    -report_end_date:required
    -report_granularity:required
    -report_project_type_id:required
    -report_program_id:required
} {
    Returns a HTML widget with the portfolio planner
} {
    set params [list \
		    [list report_start_date $report_start_date] \
		    [list report_end_date $report_end_date] \
		    [list report_granularity $report_granularity] \
		    [list report_project_type_id $report_project_type_id] \
		    [list report_program_id $report_program_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-portfolio-planner/lib/portfolio-planner"]
    return [string trim $result]
}

