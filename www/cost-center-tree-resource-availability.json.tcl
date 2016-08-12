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

# Override normal output and return this json if there was an error.
set error_json ""


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
    set cc_availability_percent_hash($cc_id) $availability_percent

    # Initialize the availability array for the interval 
    # and set the resource availability according to the cc base availability
    array unset cc_day_values
    for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {
	set available_days [expr $availability_percent / 100.0]

	# Reset weekends to zero availability
	array set date_comps [util_memoize [list im_date_julian_to_components $i]]

	set dow $date_comps(day_of_week)
	if {6 == $dow || 7 == $dow} { 
	    # Weekend
	    set available_days 0.0 
	}

	switch $granularity {
	    day { set key "$cc_id-$i" }
	    week { set key "$cc_id-[expr int($i / 7)]"  }
	    default { ad_return_complaint 1 "Invalid granularity=$granularity" }
	}

	set available 0.0
	if {[info exists available_day_hash($key)]} { set available $available_day_hash($key) }
	set available [expr $available + $available_days]
	set available_day_hash($key) $available
    }
}

# calculate the day_hash and cc_hash lists of days and CCs
foreach key [array names available_day_hash] {
    set tuple [split $key "-"]
    set cc [lindex $tuple 0]
    set i [lindex $tuple 1]
    set day_hash($i) $i
}

set date_keys [lsort -integer [array names day_hash]]
set cc_ids [lsort -integer [array names cc_hash]]
set cc_codes [qsort [array names cc_code_hash]]
set cc_ids_sorted [list]
foreach cc_code $cc_codes {
    lappend cc_ids_sorted $cc_code_hash($cc_code)
}


# ---------------------------------------------------------------
# Check open/closed status per CC
# ---------------------------------------------------------------

set open_closed_sql "
	select	cc.cost_center_id,
		ots.open_p
	from	im_cost_centers cc
		LEFT OUTER JOIN im_biz_object_tree_status ots ON (cc.cost_center_id = ots.object_id)

"
db_foreach open_closed_ccs $open_closed_sql {
    if {"" eq $open_p} { set open_p "c" }
    set cc_open_closed_hash($cost_center_id) $open_p
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

	switch $granularity {
	    day { set key "$department_id-$i" }
	    week { set key "$department_id-[expr int($i / 7)]"  }
	    default { ad_return_complaint 1 "Invalid granularity=$granularity" }
	}

	set available_days 0.0
	if {[info exists available_day_hash($key)]} { set available_days $available_day_hash($key) }

	array set date_comps [util_memoize [list im_date_julian_to_components $i]]
	set dow $date_comps(day_of_week)
	if {0 != $dow && 6 != $dow && 7 != $dow} { 
	    set available_days [expr $available_days - (1.0 * $duration_days / $absence_workdays)]
	}
	set available_day_hash($key) $available_days
    }
}


if {0} {
    set table ""
    foreach cc_id $cc_ids_sorted {
	set row "<tr><td>$cc_id</td>"
	foreach day $date_keys {
	    set key "$cc_id-$day"
	    append row "<td>$available_day_hash($key)</td>"
	}
	append table "$row</tr>"
    }

    set header "<tr><td></td>"
    foreach d $date_keys { append header "<td>$d</td>" }
    append header "</tr>"
    ad_return_complaint 1 "<table cellpadding=1 cellspacing=1>$header $table</table>"
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



# ---------------------------------------------------------------
# Calculate project assignments of resources
# ---------------------------------------------------------------

set pids [array names start_date]
if {[llength $pids] eq 0} { set error_json "'success': false, message: 'No project ids set'" }
lappend pids 0
set percentage_sql "
		select	parent.project_id as parent_project_id,
			to_char(parent.start_date, 'J') as parent_start_julian,
			to_char(parent.end_date, 'J') as parent_end_julian,
			u.user_id,
			child.project_id,
			to_char(child.start_date, 'J') as child_start_julian,
			to_char(child.end_date, 'J') as child_end_julian,
			coalesce(round(bom.percentage), 0) as percentage,
			coalesce(e.availability, 100) as availability
		from	im_projects parent,
			im_projects child,
			acs_rels r,
			im_biz_object_members bom,
			users u
			LEFT OUTER JOIN im_employees e ON (u.user_id = e.employee_id)
		where	parent.project_id in ([join $pids ","]) and
			parent.parent_id is null and
			parent.end_date >= to_date(:report_start_date, 'YYYY-MM-DD') and
			parent.start_date <= to_date(:report_end_date, 'YYYY-MM-DD') and
			not exists (select * from im_projects tt where tt.parent_id = child.project_id) and
			child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey) and
			r.rel_id = bom.rel_id and
			bom.percentage is not null and
			bom.percentage != 0 and
			r.object_id_one = child.project_id and
			r.object_id_two = u.user_id and
			u.user_id not in (select member_id from group_distinct_member_map where group_id = [im_profile_skill_profile])
			-- and parent.project_id = 37229
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
	switch $granularity {
	    day { set key "$department_id-$j" }
	    week { set key "$department_id-[expr int($j / 7)]"  }
	    default { ad_return_complaint 1 "Invalid granularity=$granularity" }
	}

	# No assignments during the weekend
	array unset date_comps
	array set date_comps [util_memoize [list im_date_julian_to_components $j]]
	set dow $date_comps(day_of_week)

	# Sum up percentages, except for weekends
	if {6 ne $dow && 7 ne $dow} {
	    set perc 0.0
	    if {[info exists assigned_day_hash($key)]} { set perc $assigned_day_hash($key) }
	    set perc [expr $perc + ($percentage * $availability) / 10000.0]
	    set assigned_day_hash($key) [expr round(100.0 * $perc) / 100.0]
	}
    }
}


if {0} {
    set table ""
    foreach cc_id $cc_ids_sorted {
	array unset cc_vars
	array set cc_vars $cc_hash($cc_id)
	set cc_code $cc_vars(cost_center_code)
	set row "<tr><td><nobr>$cc_code $cc_id</nobr></td>"
	foreach day $date_keys {
	    set key "$cc_id-$day"
	    set assigned ""
	    if {[info exists assigned_day_hash($key)]} { set assigned " / <font color=red>$assigned_day_hash($key)</font>" }
	    append row "<td><font color=blue>$available_day_hash($key)</font> $assigned</td>"
	}
	append table "$row</tr>"
    }
    set header "<tr><td></td>"
    foreach d $date_keys { append header "<td>$d</td>" }
    append header "</tr>"
    ad_return_complaint 1 "<table cellpadding=1 cellspacing=1>$header $table</table>"
}


# ---------------------------------------------------------------
# Aggregate assigned - available values along the cost center hierarchy dimension
# ---------------------------------------------------------------

# Aggregate resources assigned per cost center
foreach cc_code [lreverse $cc_codes] {

    set cc_id $cc_code_hash($cc_code)
    set super_cc_code [string range $cc_code 0 end-2]
    set super_cc_id 0
    if {[info exists cc_code_hash($super_cc_code)]} { set super_cc_id $cc_code_hash($super_cc_code) }

    set av $cc_availability_percent_hash($cc_id)
    if {"" eq $av} { set av 0 }
    set super_av 0
    if {[info exists cc_availability_percent_hash($super_cc_id)]} { set super_av $cc_availability_percent_hash($super_cc_id) }
    set super_av [expr $av + $super_av]
    set cc_availability_percent_hash($super_cc_id) $super_av
}


# Aggregate per day
foreach j $date_keys {
    foreach cc_code [lreverse $cc_codes] {

	set cc_id $cc_code_hash($cc_code)
	set super_cc_code [string range $cc_code 0 end-2]
	set super_cc_id 0
	if {[info exists cc_code_hash($super_cc_code)]} { set super_cc_id $cc_code_hash($super_cc_code) }
	set key "$cc_id-$j"
	set super_key "$super_cc_id-$j"

	set assigned 0
	set ttt 0
	if {[info exists assigned_day_hash($key)]} { set assigned $assigned_day_hash($key) }
	if {[info exists assigned_day_hash($super_key)]} { set ttt $assigned_day_hash($super_key) }
	set ttt [expr $ttt + $assigned]
	if {0 != $ttt} {
	    set assigned_day_hash($super_key) $ttt
	}

	set available 0
	set ttt 0
	if {[info exists available_day_hash($key)]} { set available $available_day_hash($key) }
	if {[info exists available_day_hash($super_key)]} { set ttt $available_day_hash($super_key) }
	set ttt [expr $ttt + $available]
	if {0 != $ttt} {
	    set available_day_hash($super_key) $ttt
	}

    }
}



if {0} {
    set table ""
    foreach cc_id $cc_ids_sorted {

	array unset cc_vars
	array set cc_vars $cc_hash($cc_id)
	set cc_code $cc_vars(cost_center_code)

	set row "<tr><td><nobr>$cc_code $cc_id</nobr></td>"
	foreach day $date_keys {
	    set key "$cc_id-$day"
	    set assigned ""
	    if {[info exists assigned_day_hash($key)]} { set assigned " / <font color=red>$assigned_day_hash($key)</font>" }
	    append row "<td><font color=blue>$available_day_hash($key)</font> $assigned</td>"
	}
	append table "$row</tr>"
    }
    set header "<tr><td></td>"
    foreach d $date_keys { append header "<td>$d</td>" }
    append header "</tr>"
    ad_return_complaint 1 "<table cellpadding=1 cellspacing=1>$header $table</table>"
}




# ---------------------------------------------------------------
# Format result as JSON
# ---------------------------------------------------------------

set valid_vars {
    cost_center_id cost_center_code cost_center_label cost_center_name 
    parent_id manager_id department_p description note cost_center_status_id 
    cost_center_type_id
}

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
    set availability_percent $cc_availability_percent_hash($cc_id)
    set cc_code_len [string length $cc_code]
    set level [expr $cc_code_len / 2]

    # ToDo: Remember open/close actions on cost centers
    set expanded "false"
    if {"o" eq $cc_open_closed_hash($cc_id)} { set expanded "true" }
    if {[string length $cc_code] < 5} { set expanded "true" }

    # Calculate the number of direct children
    set num_children 0
    foreach sub_code $cc_codes {
	if {$cc_code eq [string range $sub_code 0 [expr $cc_code_len - 1]] && $cc_code_len == [expr [string length $sub_code] - 2]} {
	    incr num_children
	}
    }

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
    set last_key ""
    for {set i $report_start_julian} {$i <= $report_end_julian} {incr i} {

	# Set the key depending on granularity
	switch $granularity {
	    day { set key "$cc_id-$i" }
	    week { set key "$cc_id-[expr int($i / 7)]"  }
	    default { ad_return_complaint 1 "Invalid granularity=$granularity" }
	}

	if {$key eq $last_key} { continue }
	set last_key $key

	# Format available days
	set days 0.0
	if {[info exists available_day_hash($key)]} {
	    set days $available_day_hash($key)
	}
	set available_day [expr round(1000.0 * $days) / 1000.0]
	if {"0.0" eq $available_day} { set available_day 0 }
	lappend available_days $available_day
	
	# Format assigned days
	set days 0.0
	if {[info exists assigned_day_hash($key)]} {
	    set days $assigned_day_hash($key)
	}
	set assigned_day [expr round(1000.0 * $days) / 1000.0]
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



if {"" ne $error_json} { set json $error_json }


