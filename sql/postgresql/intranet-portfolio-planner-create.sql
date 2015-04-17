-- /packages/intranet-portfolio-planner/sql/postgresql/intranet-portfolio-planner-create.sql
--
-- Copyright (c) 2010 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


\i intranet-portfolio-planner-workflow-create.sql


SELECT im_menu__new (
	null,						-- p_menu_id
	'im_menu',					-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creation_ip
	null,						-- context_id
	'intranet-portfolio-planner',			-- package_name
	'portfolio_planner',				-- label
	'Portfolio Planner',				-- name
	'/intranet-portfolio-planner/',			-- url
	0,						-- sort_order
	(select menu_id from im_menus where label = 'projects'),
	null						-- p_visible_tcl
);

-- ------------------------------------------------------
-- Create a REST data-source for all PMs who have not yet updated their projects
-- According to the WF
-- ------------------------------------------------------

SELECT im_report_new (
	'REST Portfolio Planner Projects Update Cases',			-- report_name
	'rest_portfolio_planner_updates',				-- report_code
	'intranet-portfolio-planner',					-- package_key
	310,								-- report_sort_order
	(select menu_id from im_menus where label = 'reporting-rest'),	-- parent_menu_id
	''
);

update im_reports set
       report_description = 'Shows PMs who have not yet confirmed a change in their project schedule.',
       report_sql = '
select	wfc.case_id,
	wfc.object_id as project_id,
	acs_object__name(wfc.object_id) as project_name,
	wft.workflow_key,
	wft.transition_key,
	wfta.party_id as user_id,
	im_name_from_user_id(wfta.party_id) as user_name,
	im_email_from_user_id(wfta.party_id) as user_email
from	portfolio_planner_change_cases ppcc, 
	wf_cases wfc,
	wf_tasks wft
	LEFT OUTER JOIN wf_task_assignments wfta ON (wft.task_id = wfta.task_id)
where	ppcc.case_id = wfc.case_id and
	wft.case_id = wfc.case_id and
	wft.state != ''finished'' and
	transition_key = ''update'''
where report_code = 'rest_portfolio_planner_updates';

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'rest_portfolio_planner_updates'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


