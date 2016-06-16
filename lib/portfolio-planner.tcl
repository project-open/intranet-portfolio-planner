# /packages/intranet-portfolio-planner/lib/portfolio-planner.tcl
#
# Copyright (c) 2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.
#
# This page is a plugin ("portlet component") used in the
# /intranet-portfolio-planner/index file.
#
# Expected variables:
#
#   report_start_date
#   report_end_date
#   report_granularity "week"
#   report_project_type_id
#   report_project_status_id
#   report_program_id

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
if {![im_permission $current_user_id "view_projects_all"]} {
    ad_return_complaint 1 "You don't have permissions to see this page"
    ad_script_abort
}

set page_url "/intranet-portfolio-planner/index"

# Load Sencha
im_sencha_extjs_load_libraries



# ---------------------------------------------------------------
# Start on a week start if report_granularity = week
# ---------------------------------------------------------------

if {"week" eq $report_granularity} {
    set report_start_julian [im_date_ansi_to_julian $report_start_date]
    array set date_comps [util_memoize [list im_date_julian_to_components $report_start_julian]]
    set dow $date_comps(day_of_week)
    set ctr 0
    while {2 != $dow && $ctr < 10} { 
	set report_start_date [db_string inc "select :report_start_date::date + 1"]
	set report_start_julian [im_date_ansi_to_julian $report_start_date]
	array set date_comps [util_memoize [list im_date_julian_to_components $report_start_julian]]
	set dow $date_comps(day_of_week)
	incr ctr
    }
}

