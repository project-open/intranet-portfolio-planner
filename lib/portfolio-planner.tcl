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



