# /packages/sencha-task-editor/www/resource-leveling-editor/main-projects-forward-load.json.tcl
#
# Copyright (c) 2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {
    Returns the list of main projects in the system,
    together with the "forward load" information,
    that is the accumulated resource assignments to
    each main project.
    Also returns the cost of the assigned resources and
    other financial measures necessary for portfolio
    management.
} {
    { project_id:integer "" }
    { project_type_id:integer "" }
    { project_status_id:integer "" }
    { exclude_project_status_id:integer "" }
    { granularity "week" }
    { program_id "" }
    { start_date ""}
    { end_date ""}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
if {![im_permission $current_user_id "view_projects_all"]} {
    ad_return_complaint 1 "You don't have permissions to see this page"
    ad_script_abort
}

set report_start_date $start_date
set report_end_date $end_date

if {"" eq $project_status_id && "" eq $exclude_project_status_id} {
    set exclude_project_status_id [im_project_status_closed]
}

# By default only show Gantt projects with Gantt tasks
if {"" == $project_type_id} {
#    set project_type_id [im_project_type_gantt]
}

# ---------------------------------------------------------------
# Extract hourly cost per user
# ---------------------------------------------------------------

set default_hourly_cost [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultTimesheetHourlyCost -default "30"]
set timesheet_hours_per_day [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetHoursPerDay -default "8"]

set hourly_cost_sql "
	select	e.employee_id,
		coalesce(e.hourly_cost, :default_hourly_cost) as hourly_cost,
		coalesce(e.availability, 100.0) as availability
	from	im_employees e
"
db_foreach hourly_cost $hourly_cost_sql {
    set employee_hourly_cost_hash($employee_id) $hourly_cost
    set employee_availability_hash($employee_id) $availability
}


# ---------------------------------------------------------------
# Get the list of "skill profiles" in order to exclude these "users" that are not real users
# ---------------------------------------------------------------

set skill_profile_user_ids [util_memoize [list db_list skill_profile_user_ids "select member_id from group_distinct_member_map where group_id = [im_profile_skill_profile]"]]


# ---------------------------------------------------------------
# Calculate resource load per day and main project
# ---------------------------------------------------------------

# ToDo: Inconsistent states:
# - work vs. assignments: Check that there is no over/underallocation
# - day fractions: Check start/end of a task for fractions
# - natural users vs. skill profiles

set main_where ""
if {"" != $report_start_date} { append main_where "\t\tand main_p.end_date::date >= :report_start_date::date\n" }
if {"" != $report_end_date} { append main_where "\t\tand main_p.start_date::date <= :report_end_date::date\n" }
if {"" != $project_status_id} { append main_where "\t\tand main_p.project_status_id in (select im_sub_categories(:project_status_id))\n" }
if {"" != $project_type_id} { append main_where "\t\tand main_p.project_type_id in (select im_sub_categories(:project_type_id))\n" }
if {"" != $project_id} { append main_where "\t\tand main_p.project_id in ([join $project_id ","])\n" }
if {"" != $program_id} { append main_where "\t\tand main_p.program_id = :program_id\n" }
if {"" != $exclude_project_status_id} { append main_where "\t\tand main_p.project_status_id not in (select im_sub_categories(:exclude_project_status_id))\n" }

set cost_bills_planned_sql ""
set cost_bills_planned_exists_p [im_column_exists im_projects cost_bills_planned]
if {$cost_bills_planned_exists_p} { set cost_bills_planned_sql "round(coalesce(main_p.cost_bills_planned::numeric, 0.0),0) as cost_bills_planned," }
set cost_bills_planned 0

set cost_expenses_planned_sql ""
set cost_expenses_planned_exists_p [im_column_exists im_projects cost_expenses_planned]
if {$cost_expenses_planned_exists_p} { set cost_expenses_planned_sql "round(coalesce(main_p.cost_expenses_planned::numeric, 0.0),0) as cost_expenses_planned," }
set cost_expenses_planned 0

set main_sql "
	select	main_p.project_id as main_project_id,
		main_p.project_name as main_project_name,
		coalesce(main_p.start_date::date, now()::date) as main_start_date,
		coalesce(main_p.end_date::date, now()::date) as main_end_date,
		main_p.description as main_description,
		coalesce(sub_p.start_date::date, now()::date) as sub_start_date,
		coalesce(sub_p.end_date::date, now()::date) as sub_end_date,

		round(coalesce(main_p.percent_completed::numeric, 0.0),1) as percent_completed,
		round(coalesce(main_p.project_budget::numeric, 0.0),0) as project_budget,
		round(coalesce(main_p.project_budget_hours::numeric, 0.0),0) as project_budget_hours,
		round(coalesce(main_p.reported_hours_cache::numeric, 0.0),0) as reported_hours_cache,
		round(coalesce(main_p.cost_quotes_cache::numeric, 0.0),0) as cost_quotes_cache,
		round(coalesce(main_p.cost_invoices_cache::numeric, 0.0),0) as cost_invoices_cache,
		round(coalesce(main_p.cost_timesheet_planned_cache::numeric, 0.0),0) as cost_timesheet_planned_cache,
		round(coalesce(main_p.cost_purchase_orders_cache::numeric, 0.0),0) as cost_purchase_orders_cache,
		round(coalesce(main_p.cost_bills_cache::numeric, 0.0),0) as cost_bills_cache,
		round(coalesce(main_p.cost_timesheet_logged_cache::numeric, 0.0),0) as cost_timesheet_logged_cache,
		round(coalesce(main_p.cost_expense_planned_cache::numeric, 0.0),0) as cost_expense_planned_cache,
		round(coalesce(main_p.cost_expense_logged_cache::numeric, 0.0),0) as cost_expense_logged_cache,
		$cost_bills_planned_sql
		$cost_expenses_planned_sql

		im_category_from_id(main_p.on_track_status_id) as on_track_status_name,
		im_category_from_id(main_p.project_status_id) as project_status,
		im_category_from_id(main_p.project_type_id) as project_type,

		p.person_id,
		to_char(coalesce(main_p.start_date::date, now()::date), 'J') as main_start_julian,
		to_char(coalesce(main_p.end_date::date, now()::date), 'J') as main_end_julian,
		to_char(coalesce(sub_p.start_date::date, now()::date), 'J') as sub_start_julian,
		to_char(coalesce(sub_p.end_date::date, now()::date), 'J') as sub_end_julian,
		coalesce(bom.percentage, 0.0) as percentage
	from	im_projects main_p,
		im_projects sub_p
		LEFT OUTER JOIN im_timesheet_tasks t ON (t.task_id = sub_p.project_id)
		LEFT OUTER JOIN acs_rels r ON (r.object_id_one = sub_p.project_id)
		LEFT OUTER JOIN im_biz_object_members bom ON (r.rel_id = bom.rel_id)
		LEFT OUTER JOIN persons p ON (r.object_id_two = p.person_id)
	where	main_p.parent_id is null and
		main_p.project_type_id not in ([im_project_type_task], [im_project_type_ticket], [im_project_type_sla], [im_project_type_program]) and
		sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
		$main_where
"


set main_var_list {percent_completed on_track_status_name project_budget project_status project_type project_budget_hours project_status project_type cost_quotes_cache cost_invoices_cache cost_timesheet_planned_cache cost_purchase_orders_cache cost_bills_cache cost_timesheet_logged_cache reported_hours_cache cost_expense_planned_cache cost_expense_logged_cache cost_bills_planned cost_expenses_planned }

db_foreach project_loop $main_sql {
    set main_project_name_hash($main_project_id) $main_project_name
    set main_project_start_julian_hash($main_project_id) $main_start_julian
    set main_project_start_date_hash($main_project_id) $main_start_date
    set main_project_end_julian_hash($main_project_id) $main_end_julian
    set main_project_end_date_hash($main_project_id) $main_end_date

    # Calculate the maximum end date of all sub-projects and tasks. This should be identical
    # the main project end_date, but maybe a task "sticks out" due to an inconsistency.
    ns_log Notice "main-projects-forward-load.json.tcl: main_project_id=$main_project_id, main_end_date=$main_end_date, sub_end_date=$sub_end_date"
    if {![info exists main_project_min_start_date_hash($main_project_id)]} { set main_project_min_start_date_hash($main_project_id) $main_start_date }
    if {$sub_start_date < $main_project_min_start_date_hash($main_project_id)} { set main_project_min_start_date_hash($main_project_id) $sub_start_date }
    if {![info exists main_project_max_end_date_hash($main_project_id)]} { set main_project_max_end_date_hash($main_project_id) $main_end_date }
    if {$sub_end_date > $main_project_max_end_date_hash($main_project_id)} { set main_project_max_end_date_hash($main_project_id) $sub_end_date }

    if {![info exists main_project_min_start_julian_hash($main_project_id)]} { set main_project_min_start_julian_hash($main_project_id) $main_start_julian }
    if {$sub_start_julian < $main_project_min_start_julian_hash($main_project_id)} { set main_project_min_start_julian_hash($main_project_id) $sub_start_julian }
    if {![info exists main_project_max_end_julian_hash($main_project_id)]} { set main_project_max_end_julian_hash($main_project_id) $main_end_julian }
    if {$sub_end_julian > $main_project_max_end_julian_hash($main_project_id)} { set main_project_max_end_julian_hash($main_project_id) $sub_end_julian }



    # Write main project fields into respective hashes
    foreach var $main_var_list {
	set cmd "set value \$$var"
	eval $cmd
	set main_project_${var}_hash($main_project_id) $value
	ns_log Notice "main-projects-forward-load.json.tcl: main_pid=$main_project_id, var=$var, value=$value"
    }

    # Initialize calculated cost of projects
    if {![info exists project_assigned_resources_cost_hash($main_project_id)]} { 
	set project_assigned_resources_cost_hash($main_project_id) 0 
    }

    # -----------------------------------------
    # Skip if no users assgined
    if {0.0 == $percentage} { continue }
    if {"" == $person_id} { continue }
    # Skip skill profiles
    if {[lsearch $skill_profile_user_ids $person_id] >= 0} { continue }


    for {set j $sub_start_julian} {$j <= $sub_end_julian} {incr j} {
	array set date_comps [util_memoize [list im_date_julian_to_components $j]]
	set dow $date_comps(day_of_week)
	set week_after_start [expr ($j-$sub_start_julian) / 7]
	set week_after_start_padded [string range "000$week_after_start" end-2 end]

	# Skip weekends
	if {0 == $dow || 6 == $dow || 7 == $dow} { continue }

	# Aggregate the subproject assignment per main project and day
	set key "$main_project_id-$j"
	set val 0.0
	if {[info exists percentage_day_hash($key)]} { set val $percentage_day_hash($key) }
	set val [expr {$val + ($percentage / 100.0)}]
	set percentage_day_hash($key) $val

	# Aggregate the cost of the subproject assignment per main project
	set key "$main_project_id"
	set val $project_assigned_resources_cost_hash($key)
	set val [expr {$val + $employee_hourly_cost_hash($person_id) * $percentage / 100.0 * $employee_availability_hash($person_id) / 100.0 * $timesheet_hours_per_day}]
	set project_assigned_resources_cost_hash($key) $val
    }
}

# ---------------------------------------------------------------
# Format result as JSON
# ---------------------------------------------------------------

set json_list [list]
set ctr 0
foreach pid [qsort [array names main_project_start_julian_hash]] {
    set project_name $main_project_name_hash($pid)
    set start_j $main_project_min_start_julian_hash($pid)
    set end_j $main_project_max_end_julian_hash($pid)
    set start_date $main_project_min_start_date_hash($pid)
    set end_date $main_project_max_end_date_hash($pid)

#    ad_return_complaint 1 "pid=$pid, start_date=$start_date, end_date=$end_date, start_j=$start_j, end_j=$end_j, week_hash=[array get week_hash]"

    # Check for funky sub-projects that "stick out" at the end of the project due to inconsistencies.
    if {$main_project_max_end_date_hash($pid) > $end_date} { set end_date $main_project_max_end_date_hash($pid) }
    
    array unset week_hash
    set vals [list]
    set max_val 0
    for {set j $start_j} {$j <= $end_j} {incr j} {
	# day
	set key_day "$pid-$j"
	set perc 0
	if {[info exists percentage_day_hash($key_day)]} { set perc $percentage_day_hash($key_day) }
	set perc_rounded [expr {round($perc * 100.0) / 100.0}]
	lappend vals $perc_rounded
	if {$perc > $max_val} { set max_val $perc }

	# Aggregate values per week
	ns_log Notice "xxx: expr ($j-$start_j) / 7"
	set week_after_start [expr ($j-$start_j) / 7]
	set week_after_start_padded [string range "000$week_after_start" end-2 end]
	set key_week "$pid-$week_after_start_padded"
	set perc_week 0.0
	if {[info exists percentage_week_hash($key_week)]} { set perc_week $percentage_week_hash($key_week) }
	set perc_week [expr {$perc_week + $perc}]
	set percentage_week_hash($key_week) $perc_week

	# Remember this week as part of a hash
	set week_hash($key_week) 1
    }

    if {"week" == $granularity} {
	set vals [list]
	set max_val 0
	foreach key_week [qsort [array names week_hash]] {
	    set perc $percentage_week_hash($key_week)
	    set perc_rounded [expr {round($perc * 100.0 / 5.0) / 100.0}]
	    lappend vals $perc_rounded
	    if {$perc_rounded > $max_val} { set max_val $perc_rounded }
	}
    }

#    ad_return_complaint 1 "pid=$pid, start_date=$start_date, end_date=$end_date, start_j=$start_j, end_j=$end_j, week_hash=[array get week_hash]"


    set percs [join $vals ", "]
    # Star the project information with some hard-coded base data
    set project_row_vals [list \
			      \"id\":$pid \
			      \"project_id\":$pid \
			      \"project_name\":\"$project_name\" \
			      \"start_date\":\"$start_date\" \
			      \"end_date\":\"$end_date\" \
    ]

    # Add a list of financial indicators
    foreach var $main_var_list {
	set cmd "set value \$main_project_${var}_hash($pid)"
	eval $cmd
	lappend project_row_vals "\"$var\":\"$value\""
    }

    # Manually calculated cost of assigned users
    lappend project_row_vals "\"assigned_resources_planned\":[expr {round($project_assigned_resources_cost_hash($pid))}]"
    set project_row_vals [concat $project_row_vals [list \
			      \"max_assigned_days\":$max_val \
			      \"assigned_days\":\[$percs\] \
    ]]

    set project_row "{[join $project_row_vals ", "]}"
    lappend json_list $project_row
    incr ctr
}

set json [join $json_list ",\n"]
set result "{\"succes\": true, \"total\": $ctr, \"message\": \"Data Loaded\", data: \[\n$json\n\]}"
doc_return 200 "text/html" $result

