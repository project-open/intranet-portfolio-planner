# /packages/intranet-portfolio-planner/www/cost-center-tree-resource-availability.json.tcl
#
# Copyright (C) 2013 ]project-open[

ad_page_contract {
    Returns a JSON tree structure suitable for batch-loading a 
    cost center tree store, together with resource availability
    information between report_start_date and report_end_date.
    The structure contains the hypothetical resource load per
    department, based on the enabled/disabled and shifted projects.

    @author frank.bergmann@project-open.com
    @param start_date: An array with the manually shifted or extended 
           projects from the planner as part of the scenario
    @param aggregate_cc_p: Should available - assigned data be
           aggregated up the cost center hierarchy? Default is yes.
} {
    { start_date:array,optional }
    { end_date:array,optional }
    { report_start_date "" }
    { report_end_date "" }
    { granularity "week" }
    { aggregate_cc_p 1}
    {debug_p 1}
}


# --------------------------------------------
# Security & Permissions
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
# No restrictions on the cost center load, really. There aren't many usefule information there?!?
set read [im_permission $current_user_id "view_projects_all"]
if {!$read} {
    im_rest_error -format "json" -http_status 403 -message "User #$current_user_id has no permissions to read the list of projects"
    ad_script_abort
}

if {"" == $report_start_date} { set report_start_date [db_string now "select (now()::date - '1 month'::interval)::date"] }
if {"" == $report_end_date} { set report_end_date [db_string now "select (now()::date + '1 year'::interval)::date"] }

set report_start_date [string range $report_start_date 0 9]
set report_end_date [string range $report_end_date 0 9]

set report_start_julian [im_date_ansi_to_julian $report_start_date]
set report_end_julian [im_date_ansi_to_julian $report_end_date]


# ---------------------------------------------------------------
# Calculate available resources per cost_center
# ---------------------------------------------------------------

# Cost_Centers hash cost_center_id -> hash(CC vars) + "availability_percent"
array set cc_hash [im_resource_management_cost_centers \
		       -start_date $report_start_date \
		       -end_date $report_end_date \
		       -limit_to_ccs_with_resources_p 0 \
]
# ad_return_complaint 1 "<pre>[join [array get cc_hash] "\n"]</pre>"

# Initialize availalable resources per cost_center and day
set cnt 0
foreach cc_id [lsort -integer [array names cc_hash]] {
    incr cnt
    array unset cc_values
    array set cc_values $cc_hash($cc_id)
    set availability_percent $cc_values(availability_percent)
    if {"" == $availability_percent} { set availability_percent 0.0 }

    # Create index from CC codes to cc IDs
    set cc_code $cc_values(cost_center_code)
    set cc_code_hash($cc_code) $cc_id

    # Initialize the availability array for the interval 
    # and set the resource availability according to the cc base availability
    array unset cc_day_values
    for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {
	set available_days [expr {$availability_percent / 100.0}]

	# Reset weekends to zero availability
	array set date_comps [util_memoize [list im_date_julian_to_components $i]]
	set dow $date_comps(day_of_week)
	if {6 == $dow || 7 == $dow} { 
	    # Weekend
	    set available_days 0.0 
	}

	set key "$cc_id-$i"
	set available_day_hash($key) $available_days
    }
}



# ---------------------------------------------------------------
# Subtract vacations from available days
# ---------------------------------------------------------------

# Absences hash absence_id -> hash(absence vars)
array set absence_hash [im_resource_management_user_absences \
			    -start_date $report_start_date \
			    -end_date $report_end_date \
]
#ad_return_complaint 1 [array get absence_hash]

foreach aid [array names absence_hash] {
    array unset absence_values
    array set absence_values $absence_hash($aid)
    set absence_start_date [string range $absence_values(start_date) 0 9]
    set absence_end_date [string range $absence_values(end_date) 0 9]
    set duration_days $absence_values(duration_days)
    set absence_workdays $absence_values(absence_workdays)
    set department_id $absence_values(department_id)
    set absence_type_id $absence_values(absence_type_id)

    set end_julian [im_date_ansi_to_julian $absence_end_date]
    for {set i [im_date_ansi_to_julian $absence_start_date]} {$i <= $end_julian} {incr i} {
	set key "$department_id-$i"
	set available_days 0.0
	if {[info exists available_day_hash($key)]} { set available_days $available_day_hash($key) }

	array set date_comps [util_memoize [list im_date_julian_to_components $i]]
	set dow $date_comps(day_of_week)
	if {0 != $dow && 6 != $dow && 7 != $dow} { 
	    set available_days [expr {$available_days - (1.0 * $duration_days / $absence_workdays)}]
	}
	set available_day_hash($key) $available_days	
    }
}


if {0} {
    set table ""
    foreach cc_id [array names cc_hash] {
	append table "<tr><td>$cc_id</td>"
	for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {
	    set key "$cc_id-$i"
	    append table "<td><nobr>$available_day_hash($key)</nobr></td>"
	}
	append table "</tr>"
    }
    ad_return_complaint 1 "<table cellpadding=1 cellspacing=1>$table</table>"
}


# ---------------------------------------------------------------
# Store employee availability information in hash
# ---------------------------------------------------------------

set default_cost_center_id [im_cost_center_company]
set employee_sql "
	select	u.user_id,
		coalesce(e.availability, 100) as availability,
		coalesce(e.department_id, :default_cost_center_id) as department_id
	from	users u
		LEFT OUTER JOIN im_employees e ON (u.user_id = e.employee_id)
"
db_foreach emp $employee_sql {
    set employee_department_hash($user_id) $department_id
    set employee_availability_hash($user_id) $availability
}


# ---------------------------------------------------------------
# Calculate the required project resources during the interval
# with the modified project start- and end dates
# ---------------------------------------------------------------

# Store the julian start- and end dates for the main projects
foreach pid [array names start_date] {
    set start_ansi $start_date($pid);
    set start_julian [im_date_ansi_to_julian $start_ansi]
    set end_ansi $end_date($pid);
    set end_julian [im_date_ansi_to_julian $end_ansi]

    set start_julian_hash($pid) $start_julian
    set end_julian_hash($pid) $end_julian
}

set pids [array names start_date]
lappend pids 0
set percentage_sql "
		select
			parent.project_id as parent_project_id,
			to_char(parent.start_date, 'J') as parent_start_julian,
			to_char(parent.end_date, 'J') as parent_end_julian,
			u.user_id,
			child.project_id,
			to_char(child.start_date, 'J') as child_start_julian,
			to_char(child.end_date, 'J') as child_end_julian,
			coalesce(round(bom.percentage), 0) as percentage
		from
			im_projects parent,
			im_projects child,
			acs_rels r,				-- no left outer join - show only assigned users
			im_biz_object_members bom,
			users u
		where
			parent.project_id in ([join $pids ","]) and
			parent.parent_id is null and
			parent.end_date >= to_date(:report_start_date, 'YYYY-MM-DD') and
			parent.start_date <= to_date(:report_end_date, 'YYYY-MM-DD') and
			child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
			r.rel_id = bom.rel_id and
			bom.percentage is not null and		-- skip assignments without percentage
			r.object_id_one = child.project_id and
			r.object_id_two = u.user_id
			-- Testing
			-- and parent.project_id = 171036	-- Fraber Test 2015
"
db_foreach projects $percentage_sql {
    set pid_start_julian $start_julian_hash($parent_project_id)
    set pid_end_julian $end_julian_hash($parent_project_id)
    set parent_date_shift [expr $pid_start_julian - $parent_start_julian]
    # ToDo: incorporate if the project has been dragged to be longer

    set child_start_julian [expr $child_start_julian + $parent_date_shift]
    set child_end_julian [expr $child_end_julian + $parent_date_shift]
    set department_id $employee_department_hash($user_id)

    for {set j $child_start_julian} {$j <= $child_end_julian} {incr j} {
	set key "$department_id-$j"
	set perc 0.0
	if {[info exists assigned_day_hash($key)]} { set perc $assigned_day_hash($key) }
	set perc [expr {$perc + $percentage / 100.0}]

	array set date_comps [util_memoize [list im_date_julian_to_components $j]]
	set dow $date_comps(day_of_week)

	if {6 == $dow || 7 == $dow} { set perc 0.0 }
	set assigned_day_hash($key) $perc
    }
}

if {0} {
    set table ""
    foreach cc_id [array names cc_hash] {
	append table "<tr><td>$cc_id</td>"
	for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {
	    set key "$cc_id-$i"
	    
	    set assigned 0
	    set available 0
	    if {[info exists assigned_day_hash($key)]} { set assigned $assigned_day_hash($key) }
	    if {[info exists available_day_hash($key)]} { set available $available_day_hash($key) }

	    append table "<td><nobr>$available - $assigned</nobr></td>"
	}
	append table "</tr>"
    }
    ad_return_complaint 1 "<table cellpadding=1 cellspacing=1>$table</table>"
}


# ---------------------------------------------------------------
# Aggregate assigned - available values:
# 1. Along the cost center hierarchy
# 2. According to the daily/weekly/monthly granularity
# ---------------------------------------------------------------

# ToDo

# ---------------------------------------------------------------
# Format result as JSON
# ---------------------------------------------------------------

# Create the hierarchical list of CCs
set cc_codes [qsort [array names cc_code_hash]]
# ad_return_complaint 1 $cc_codes
# ad_return_complaint 1 "<pre>[join [array get cc_hash] "\n"]</pre>"

set valid_vars {cost_center_id cost_center_code cost_center_label cost_center_name parent_id manager_id department_p description note cost_center_status_id cost_center_type_id department_planner_days_per_year}

set ctr 0
set old_level 1
set indent ""
set json ""
foreach cc_code $cc_codes {

    # Gather information about the current CC
    set cc_id $cc_code_hash($cc_code)
    array unset cc_values
    array set cc_values $cc_hash($cc_id)
    set cc_name $cc_values(cost_center_name)
    set availability_percent $cc_values(availability_percent)
    if {"" eq $availability_percent} { set availability_percent 0 }
    set cc_code_len [string length $cc_code]
    set level [expr $cc_code_len / 2]
    set expanded "true"


    # Calculate the number of direct children
    set num_children 0
    foreach sub_code $cc_codes {
	if {$cc_code eq [string range $sub_code 0 [expr $cc_code_len - 1]] && $cc_code_len == [expr [string length $sub_code] - 2]} {
	    incr num_children
	}
    }

    ns_log Notice "cost-center-tree-resource-availability.json.tcl: code=$cc_code, level=$level, id=$cc_id"

    # -----------------------------------------
    # Close off the previous entry
    # -----------------------------------------
    
    # This is the first child of the previous item
    # Increasing the level always happens in steps of 1
    if {$level > $old_level} {
	append json ",\n${indent}\tchildren:\[\n"
    }

    # A group of children needs to be closed.
    # Please note that this can cascade down to several levels.
    while {$level < $old_level} {
	append json "\n${indent}\}\]\n"
	incr old_level -1
	set indent ""
	for {set i 0} {$i < $old_level} {incr i} { append indent "\t" }
    }

    # The current cost_center is on the same level as the previous.
    # This is also executed after reducing the old_level in the previous while loop
    if {$level == $old_level} {
	if {0 != $ctr} { 
	    append json "${indent}\n${indent}\},\n"
	}
    }


    # -----------------------------------------
    # Format the list of available - assigned days
    # -----------------------------------------

    set available_days [list]
    set assigned_days [list]
    for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {
	set key "$cc_id-$i"

	# Format available days
	set days 0.0
	if {[info exists available_day_hash($key)]} {
	    set days $available_day_hash($key)
	}
	set available_day [expr {round(1000.0 * $days) / 1000.0}]
	if {"0.0" eq $available_day} { set available_day 0 }
	lappend available_days $available_day
	
	# Format assigned days
	set days 0.0
	if {[info exists assigned_day_hash($key)]} {
	    set days $assigned_day_hash($key)
	}
	set assigned_day [expr {round(1000.0 * $days) / 1000.0}]
	if {"0.0" eq $assigned_day} { set assigned_day 0 }
	lappend assigned_days $assigned_day
    }


    # -----------------------------------------
    # Format the JSON output
    # -----------------------------------------

    set indent ""
    for {set i 0} {$i < $level} {incr i} { append indent "\t" }
    if {0 == $num_children} { set leaf_json "true" } else { set leaf_json "false" }
    set quoted_char_map {"\n" "\\n" "\r" "\\r" "\"" "\\\"" "\\" "\\\\"}
    set quoted_cc_name [string map $quoted_char_map $cc_name]

    set available_list [join $available_days ","]
    set assigned_list [join $assigned_days ","]

    append json "${indent}\{
${indent}\tid:$cc_id,
${indent}\tassigned_resources:$availability_percent,
${indent}\tavailable_days:\[$available_list\],
${indent}\tassigned_days:\[$assigned_list\],
${indent}\texpanded:$expanded,
"

    foreach var $valid_vars {
	# Skip xml_* variables (only used by MS-Project)
	if {[regexp {^xml_} $var match]} { continue }

	# Append the value to the JSON output
	set value $cc_values($var)
	set quoted_value [string map $quoted_char_map $value]
	append json "${indent}\t$var:\"$quoted_value\",\n"
    }

    # Add hard-coded field "leaf" at the end, to avoid a trailing comma ","
    append json "${indent}\tleaf:$leaf_json"

    incr ctr
    set old_level $level
}

set level 0
while {$level < $old_level} {
    # A group of children needs to be closed.
    # Please note that this can cascade down to several levels.
    append json "\n${indent}\}\]\n"
    incr old_level -1
    set indent ""
    for {set i 0} {$i < $old_level} {incr i} { append indent "\t" }
}

